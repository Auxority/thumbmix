import OSLog
import SwiftUI
import ThumbmixCore
import TipKit

/// Turns a `SoloHold` on the overview into a stroke on the mirror: which row the finger is over, a tick per row
/// changed, and the list scrolling on while the finger rests near its top or bottom edge, as in Photos.
@MainActor @Observable
final class SoloStrokeDriver {
    nonisolated static var space: NamedCoordinateSpace { .named("overview") }

    /// Each row's frame in the overview's visible area (`space`); rows the lazy list hasn't built have none.
    var frames: [OverviewItem: CGRect] = [:]
    var viewportHeight: CGFloat = 0
    /// The rows end in a glass bar the list scrolls under; the bottom edge zone sits above it.
    var bottomInset: CGFloat = 0
    private(set) var ticks = 0
    private(set) var held: OverviewItem?
    /// The finger lifted on rows held back for the Exclusive solo question.
    var isAskingExclusive = false
    @ObservationIgnored private var rows: [OverviewItem] = []
    @ObservationIgnored private var fingerY: CGFloat = 0
    @ObservationIgnored private var edgeScroll: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "thumbmix", category: "solo")

    func hold(
        _ phase: SoloHold.Phase, at point: CGPoint, on item: OverviewItem, rows listed: [OverviewItem],
        mirror: ConsoleMirror, proxy: ScrollViewProxy
    ) {
        fingerY = point.y
        switch phase {
        case .began: begin(on: item, rows: listed, mirror: mirror, proxy: proxy)
        case .moved: track(mirror)
        case .ended: end(mirror)
        }
    }

    private func begin(on item: OverviewItem, rows listed: [OverviewItem], mirror: ConsoleMirror, proxy: ScrollViewProxy) {
        guard let start = listed.firstIndex(of: item) else {
            log.error("solo hold on a row not in the list: \(item.id, privacy: .public)")
            return
        }
        rows = listed
        let ticked = mirror.beginSoloStroke(listed, at: start)
        log.info("solo stroke at row \(start) of \(listed.count): \(ticked.isEmpty ? "refused" : "started")")
        guard !ticked.isEmpty else { return }
        held = item
        ticks += 1
        edgeScroll = Task { [weak self] in await self?.scrollAtEdges(mirror, proxy) }
        Task { await SoloStrokeTip.soloedByHolding.donate() }
    }

    private func track(_ mirror: ConsoleMirror) {
        guard held != nil, let row = row(at: fingerY) else { return }
        if !mirror.moveSoloStroke(to: row).isEmpty { ticks += 1 }
    }

    private func end(_ mirror: ConsoleMirror) {
        guard held != nil else { return }
        edgeScroll?.cancel()
        held = nil
        isAskingExclusive = mirror.endSoloStroke()
    }

    /// The mirror dropped the stroke without a lift (contact lost, Clear, the app sent away): stop following the
    /// finger, and close a question that no longer has rows to answer for.
    func strokeEnded() {
        edgeScroll?.cancel()
        held = nil
        isAskingExclusive = false
    }

    /// The row under the finger, or the nearest built one when it's in the gap between two.
    private func row(at y: CGFloat) -> Int? {
        let built = rows.indices.compactMap { index in frames[rows[index]].map { (index, $0) } }
        return built.min { distance(y, $0.1) < distance(y, $1.1) }?.0
    }

    private func distance(_ y: CGFloat, _ frame: CGRect) -> CGFloat {
        frame.minY <= y && y <= frame.maxY ? 0 : min(abs(y - frame.minY), abs(y - frame.maxY))
    }

    /// While the finger rests in an edge zone, one more row comes into view at a time, faster the longer it stays.
    private func scrollAtEdges(_ mirror: ConsoleMirror, _ proxy: ScrollViewProxy) async {
        var steps = 0
        while !Task.isCancelled {
            let direction = edgeDirection()
            steps = direction == 0 ? 0 : steps + 1
            if direction != 0, let next = nextRow(direction) {
                withAnimation(.linear(duration: 0.15)) { proxy.scrollTo(rows[next], anchor: direction > 0 ? .bottom : .top) }
                try? await Task.sleep(for: .milliseconds(160))
                track(mirror)
            }
            try? await Task.sleep(for: .milliseconds(max(60, 300 - steps * 30)))
        }
    }

    private func edgeDirection() -> Int {
        if fingerY < 56 { return -1 }
        if fingerY > viewportHeight - bottomInset - 56 { return 1 }
        return 0
    }

    private func nextRow(_ direction: Int) -> Int? {
        guard let current = row(at: fingerY) else { return nil }
        let next = current + direction
        return rows.indices.contains(next) ? next : nil
    }
}

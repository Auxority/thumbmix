import Foundation

/// Which part of the colour stripe a row lights: a linked pair's sides split it, top for the odd (left) side.
public enum StripeHalf: Hashable, Sendable {
    case full, top, bottom
}

/// One overview row: a strip, or a linked pair whose faders move together (held by its odd side).
public enum OverviewItem: Hashable, Identifiable, Sendable {
    case strip(StripID, StripeHalf)
    case pair(StripID)

    public var id: String {
        switch self {
        case .strip(let strip, _): strip.prefix
        case .pair(let odd): "pair" + odd.prefix
        }
    }

    /// The strip whose controls the row shows: a pair's, like its screen, belong to its odd side.
    public var held: StripID {
        switch self {
        case .strip(let strip, _): strip
        case .pair(let odd): odd
        }
    }

    /// Whether `strip` is this row's: a pair's row stands for both its sides.
    public func holds(_ strip: StripID) -> Bool {
        switch self {
        case .strip(let own, _): own == strip
        case .pair(let odd): strip.oddSide == odd
        }
    }

    /// The strip screen the row opens: a pair's screen belongs to its odd side.
    public var opens: StripID {
        switch self {
        case .strip(let strip, .full): strip
        case .strip(let strip, _): strip.oddSide
        case .pair(let odd): odd
        }
    }
}

extension ConsoleMirror {
    /// While true, rows must not change shape: the finger owns a control.
    public var isFingerDown: Bool { holds.isFingerDown }

    /// Returns once no finger owns a control; throws when cancelled. Lifting a finger isn't observed, so it looks
    /// every 100 ms.
    public func fingerLifted() async throws {
        while isFingerDown { try await Task.sleep(for: .milliseconds(100)) }
    }

    /// The rows for `strips`. A pair is unused, and hidden, only when both its sides are.
    public func overviewItems(_ strips: [StripID], showUnused: Bool) -> [OverviewItem] {
        strips.compactMap { strip in
            guard isLinked(strip), let partner = strip.partner else {
                return showUnused || !isUnused(strip) ? .strip(strip, .full) : nil
            }
            guard showUnused || !(isUnused(strip) && isUnused(partner)) else { return nil }
            return pairItem(for: strip)
        }
    }

    /// A pair's row goes by what both names share ("Gtr"); a half row by its own side's name.
    public func title(of item: OverviewItem) -> String {
        if case .pair(let odd) = item { return pairName(odd) }
        return name(item.held)
    }

    /// The desk number under a Sends or Fed by row's name, as the overview shows it but with the kind ("Ch 9-10"):
    /// Fed by mixes kinds. nil while the row is unnamed: its title, "Ch 20", already holds the number.
    public func numberCaption(of item: OverviewItem) -> String? {
        switch item {
        case .strip(let strip, _):
            return rawName(strip).isEmpty ? nil : strip.defaultName
        case .pair(let odd):
            let sides = [odd, odd.partner ?? odd]
            return sides.allSatisfy { rawName($0).isEmpty } ? nil : odd.pairDefaultName
        }
    }

    /// On Main LR a row's level is the strip's own fader, which moves its post-fader sends too, so the caption names
    /// it (mock F1, 2026-10-13): "Ch 1 · Fader". Elsewhere it's a send, and the number alone.
    public func fedByCaption(of item: OverviewItem, on target: StripID) -> String? {
        let number = numberCaption(of: item)
        guard target.kind == .mainStereo else { return number }
        return [number, Catalog.fader(item.held).label].compactMap { $0 }.joined(separator: " · ")
    }

    private func pairItem(for strip: StripID) -> OverviewItem? {
        let isOdd = strip == strip.oddSide
        guard !isShared(.faderMute) else { return isOdd ? .pair(strip) : nil }
        return .strip(strip, isOdd ? .top : .bottom)
    }
}

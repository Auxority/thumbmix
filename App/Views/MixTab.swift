import SwiftUI
import ThumbmixCore

/// The strip's full level controls: fader with meter, ±1 dB nudges, mute and pan.
struct MixTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// The other side of a linked pair: the fader is shared, but each side keeps its own pan.
    var panPartner: StripID?

    var body: some View {
        VStack(spacing: 10) {
            ParameterRow(
                spec: Catalog.fader(strip), mirror: mirror, accent: Theme.color(mirror.color(strip)), height: 72,
                meter: mirror.meter(strip))
            HStack(spacing: 10) {
                NudgeButton(label: "−1 dB", fader: Catalog.fader(strip).address, mirror: mirror) { nudge(by: -1) }
                NudgeButton(label: "+1 dB", fader: Catalog.fader(strip).address, mirror: mirror) { nudge(by: 1) }
                MuteButton(strip: strip, mirror: mirror, title: "MUTE", width: 96, height: 52)
            }
            if let panPartner {
                ForEach([strip, panPartner]) { side in panRow(side, title: "Pan · \(mirror.name(side))") }
            } else {
                panRow(strip, title: nil)
            }
            if strip.linkAddress != nil { LinkButton(strip: strip, mirror: mirror) }
        }
    }

    @ViewBuilder private func panRow(_ side: StripID, title: String?) -> some View {
        if let pan = Catalog.pan(side) {
            ParameterRow(spec: pan, mirror: mirror, title: title, height: 44)
        }
    }

    private func nudge(by decibels: Double) {
        let fader = Catalog.fader(strip)
        guard let current = mirror.normalized(fader) else { return }
        let next = RelativeDrag.nudged(current, byDecibels: decibels, scale: fader.scale)
        mirror.set(fader.address, fader.scale.argument(fromNormalized: next))
    }
}

/// Above every tab but Mix, so the engineer can pull or mute a channel that rings while editing its EQ.
struct SlimMixRow: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        HStack(spacing: 10) {
            ParameterRow(
                spec: Catalog.fader(strip), mirror: mirror, accent: Theme.color(mirror.color(strip)), height: 44,
                meter: mirror.meter(strip))
            MuteButton(strip: strip, mirror: mirror, title: "MUTE", width: 80, height: 44)
        }
    }
}

/// Steps once on touch-down and repeats while held (`NudgeRepeat`). The finger owns the fader for the whole hold,
/// so the desk's echoes of earlier steps can't pull it back mid-hold.
private struct NudgeButton: View {
    let label: LocalizedStringKey
    let fader: String
    let mirror: ConsoleMirror
    let step: () -> Void
    @State private var repeating: Task<Void, Never>?
    @ScaledMetric private var minHeight: CGFloat = 52

    var body: some View {
        Text(label)
            .font(.headline.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(repeating == nil ? Theme.raised : Theme.selected, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in press() }.onEnded { _ in release() })
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { step() }
    }

    private func press() {
        guard repeating == nil else { return }
        mirror.beginEdit(fader)
        step()
        repeating = Task { await repeatWhileHeld() }
    }

    private func release() {
        repeating?.cancel()
        repeating = nil
        mirror.endEdit(fader)
    }

    private func repeatWhileHeld() async {
        let start = ContinuousClock.now
        try? await Task.sleep(for: NudgeRepeat.firstRepeat)
        while !Task.isCancelled {
            step()
            try? await Task.sleep(for: NudgeRepeat.interval(afterHolding: .now - start))
        }
    }
}

#if DEBUG
    #Preview {
        VStack(spacing: 20) {
            MixTab(strip: StripID(.input, 1), mirror: .preview())
            SlimMixRow(strip: StripID(.input, 1), mirror: .preview())
        }
        .padding()
        .background(Theme.background)
    }
#endif

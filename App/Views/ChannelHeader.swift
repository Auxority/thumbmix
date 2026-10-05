import SwiftUI
import ThumbmixCore

struct ChannelHeader: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        let color = Theme.color(mirror.color(strip))
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 8, height: 28)
                Text(mirror.name(strip)).font(.title2.bold()).lineLimit(1)
                Spacer()
            }
            ParameterRow(
                spec: Catalog.fader(strip), mirror: mirror, accent: color, height: 72,
                meter: mirror.meter(strip))
            HStack(spacing: 10) {
                NudgeButton(label: "−1 dB") { nudge(by: -1) }
                NudgeButton(label: "+1 dB") { nudge(by: 1) }
                MuteButton(strip: strip, mirror: mirror, title: "MUTE", width: 96, height: 52)
            }
            if let pan = Catalog.pan(strip) {
                ParameterRow(spec: pan, mirror: mirror, height: 44)
            }
        }
    }

    private func nudge(by decibels: Double) {
        let fader = Catalog.fader(strip)
        guard let current = mirror.normalized(fader) else { return }
        let next = RelativeDrag.nudged(current, byDecibels: decibels, scale: fader.scale)
        mirror.set(fader.address, fader.scale.argument(fromNormalized: next))
    }
}

private struct NudgeButton: View {
    let label: LocalizedStringKey
    let action: () -> Void
    @ScaledMetric private var minHeight: CGFloat = 52

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

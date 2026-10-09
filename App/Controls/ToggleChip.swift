import SwiftUI
import ThumbmixCore

struct ToggleChip: View {
    let spec: ParamSpec
    let mirror: ConsoleMirror
    var title: String?
    var onColor: Color = .white
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let isOn = mirror.cell(spec.address).argument == .int(1)
        Button {
            mirror.set(spec.address, .int(isOn ? 0 : 1))
        } label: {
            Text(title ?? spec.label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(minWidth: 52 * sizeScale, minHeight: 44 * sizeScale)
                .padding(.horizontal, 8)
                .foregroundStyle(isOn ? .black : Theme.secondaryText)
                .background(isOn ? onColor : Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("toggle-" + spec.address)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// Lit red when muted. On the M32 mute is `mix/on` = 0.
struct MuteButton: View {
    let strip: StripID
    let mirror: ConsoleMirror
    var title = "M"
    var width: CGFloat = 48
    var height: CGFloat = 48
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let muted = mirror.isMuted(strip)
        let name = mirror.isLinked(strip) ? mirror.pairName(strip) : mirror.name(strip)
        Button {
            mirror.set(strip.on, .int(muted ? 1 : 0))
        } label: {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width * sizeScale, height: height * sizeScale)
                .foregroundStyle(muted ? .white : Theme.secondaryText)
                .background(muted ? Theme.muteRed : Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mute-" + strip.on)
        // A list of plain "Mute"s doesn't say which strip each one mutes.
        .accessibilityLabel(muted ? "Unmute \(name)" : "Mute \(name)")
    }
}

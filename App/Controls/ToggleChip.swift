import SwiftUI
import ThumbmixCore

struct ToggleChip: View {
    let spec: ParamSpec
    let mirror: ConsoleMirror
    var title: String?
    var onColor: Color = .white
    var onText: Color = .black
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let state = mirror.cell(spec.address).argument
        let isOn = state == .int(1)
        Button {
            mirror.set(spec.address, .int(isOn ? 0 : 1))
        } label: {
            Text(title ?? spec.label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(minWidth: 52 * sizeScale, minHeight: 44 * sizeScale)
                .padding(.horizontal, 8)
                .foregroundStyle(isOn ? onText : Theme.secondaryText)
                .background(isOn ? onColor : Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(state == nil)
        // Dimmed like a disabled ParameterRow: an unread chip in full grey would still read as a real "Off".
        .opacity(isEnabled && state != nil ? 1 : 0.38)
        .accessibilityIdentifier("toggle-" + spec.address)
        .accessibilityValue(state == nil ? Text(verbatim: "") : Text(isOn ? "On" : "Off"))
    }
}

/// Lit red when muted. On the M32 mute is `mix/on` = 0.
struct MuteButton: View {
    let strip: StripID
    let mirror: ConsoleMirror
    var title = "M"
    /// nil fills the row, as beside SOLO on the Mix tab.
    var width: CGFloat? = 48
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
                .frame(width: width.map { $0 * sizeScale }, height: height * sizeScale)
                .frame(maxWidth: width == nil ? .infinity : nil)
                .foregroundStyle(muted ? .white : Theme.secondaryText)
                .background(muted ? Theme.muteRed : Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mute-" + strip.on)
        // A list of plain "Mute"s doesn't say which strip each one mutes.
        .accessibilityLabel(muted ? "Unmute \(name)" : "Mute \(name)")
    }
}

/// Lit yellow while soloed, like the desk's. A linked pair solos both sides (`ConsoleMirror.toggleSolo`).
struct SoloButton: View {
    let strip: StripID
    let mirror: ConsoleMirror
    var title = "SOLO"
    /// nil fills the row, as beside MUTE on the Mix tab.
    var width: CGFloat?
    var height: CGFloat = 52
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let soloed = mirror.isSoloed(strip)
        let name = mirror.isLinked(strip) ? mirror.pairName(strip) : mirror.name(strip)
        Button {
            mirror.toggleSolo(strip)
        } label: {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width.map { $0 * sizeScale }, height: height * sizeScale)
                .frame(maxWidth: width == nil ? .infinity : nil)
                .foregroundStyle(soloed ? .black : Theme.secondaryText)
                .background(soloed ? Theme.soloYellow : Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("solo-" + strip.solo)
        .accessibilityLabel(soloed ? "Unsolo \(name)" : "Solo \(name)")
    }
}

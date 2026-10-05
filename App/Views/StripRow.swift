import SwiftUI
import ThumbmixCore

struct StripRow: View {
    let strip: StripID
    let mirror: ConsoleMirror
    let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric private var nameWidth: CGFloat = 78

    var body: some View {
        // At accessibility text sizes a 375 pt row can't fit name, fader and mute side by side.
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                nameButton
                HStack(spacing: 8) { faderAndMute }
            }
        } else {
            HStack(spacing: 8) {
                nameButton.frame(width: nameWidth + 14, alignment: .leading)
                faderAndMute
            }
        }
    }

    private var color: Color { Theme.color(mirror.color(strip)) }

    private var nameButton: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 6, height: 40)
                Text(mirror.name(strip))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mirror.name(strip))
    }

    @ViewBuilder private var faderAndMute: some View {
        ParameterRow(
            spec: Catalog.fader(strip), mirror: mirror, title: "", accent: color, height: 52,
            meter: mirror.meter(strip))
        MuteButton(strip: strip, mirror: mirror, height: 52)
    }
}

#if DEBUG
    #Preview {
        let mirror = ConsoleMirror.preview()
        return VStack(spacing: 6) {
            ForEach(StripID.all(.input).prefix(4)) { StripRow(strip: $0, mirror: mirror) {} }
        }
        .padding(12)
        .background(Theme.background)
    }
#endif

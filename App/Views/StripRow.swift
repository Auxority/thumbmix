import SwiftUI
import ThumbmixCore

struct StripRow: View {
    let strip: StripID
    let mirror: ConsoleMirror
    let onOpen: () -> Void

    var body: some View {
        let color = Theme.color(mirror.color(strip))
        HStack(spacing: 8) {
            Button(action: onOpen) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 6, height: 40)
                    Text(mirror.name(strip))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 78, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mirror.name(strip))
            ParameterRow(spec: Catalog.fader(strip), mirror: mirror, title: "", accent: color, height: 52, meter: mirror.meter(strip))
            MuteButton(strip: strip, mirror: mirror, height: 52)
        }
    }
}

import SwiftUI
import ThumbmixCore

/// L | R for a tab whose section the desk doesn't link, so the two sides can differ; with the reason underneath.
struct PairSidePicker: View {
    let odd: StripID
    let tab: ChannelTab
    let mirror: ConsoleMirror
    @Binding var showsRight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                sideButton("L", strip: odd, isRight: false)
                sideButton("R", strip: odd.partner ?? odd, isRight: true)
            }
            .padding(2)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
            Text(hint).font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }

    private func sideButton(_ letter: String, strip: StripID, isRight: Bool) -> some View {
        let isSelected = showsRight == isRight
        return Button {
            showsRight = isRight
        } label: {
            Text(verbatim: "\(letter) · \(mirror.name(strip))")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? .black : .white)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(isSelected ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("side-" + letter)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var hint: LocalizedStringKey {
        switch tab {
        case .sends: "Sends aren't linked on the desk."
        case .input: "Gain and delay aren't linked on the desk."
        case .eq: "EQ isn't linked on the desk."
        case .gate, .comp: "Dynamics aren't linked on the desk."
        default: "Fader and mute aren't linked on the desk."
        }
    }
}

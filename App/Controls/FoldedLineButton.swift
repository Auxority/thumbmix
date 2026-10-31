import SwiftUI
import ThumbmixCore

/// The one line a set-once block folds into (mock B, 2026-10-20): what's inside over its values, and a › that opens
/// them in a sheet. The tab never changes length, so nothing moves under the finger.
struct FoldedLineButton: View {
    let line: FoldedLine
    let identifier: String
    let action: () -> Void
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: line.names).font(.footnote).foregroundStyle(Theme.secondaryText)
                        .truncationMode(.tail)
                    // A long key ("RMS · LOG · After EQ · Ch 13 · Acoustic Gtr") shrinks, then is cut in the middle:
                    // the On/Off at its end always shows (2026-10-31).
                    Text(values).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 56 * sizeScale)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: line.names))
        .accessibilityValue(Text(verbatim: line.text))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }

    /// The values, then each state as a green "On" or a grey "Off" ("Filter on" on a Key line), like the chips
    /// (B, 2026-10-20).
    private var values: AttributedString {
        var text = AttributedString(line.values)
        for (index, isOn) in line.states.enumerated() {
            if index > 0 || !line.values.isEmpty { text += AttributedString(index == 0 ? " · " : " / ") }
            var word = AttributedString(line.word(isOn))
            word.foregroundColor = isOn ? .green : Theme.secondaryText
            text += word
        }
        return text
    }
}

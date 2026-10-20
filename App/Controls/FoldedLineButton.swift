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
                    Text(verbatim: line.values).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                }
                .lineLimit(1)
                .truncationMode(.tail)
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
        .accessibilityValue(Text(verbatim: line.values))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}

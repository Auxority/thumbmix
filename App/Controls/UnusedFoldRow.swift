import SwiftUI
import ThumbmixCore

/// The last row of a list that folds its unused strips (mock A1, 2026-10-14): "6 unused · Ch 3, 6, 13–14 · Show".
/// Show and Hide add or remove rows above it; its list keeps its bottom in place (`keepsFoldInPlace`), so the row
/// stays under the finger (the user, 2026-10-14).
struct UnusedFoldRow: View {
    static let id = "unused-fold"
    /// One open fold per kind of list, kept across launches (the user, 2026-10-14).
    static let overviewKey = "unusedShown.overview"
    static let sendsKey = "unusedShown.sends"
    static let fedByKey = "unusedShown.fedBy"
    static let storageKeys = [overviewKey, sendsKey, fedByKey]
    let strips: [StripID]
    @Binding var isOpen: Bool

    var body: some View {
        Button {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { isOpen.toggle() }
        } label: {
            HStack(spacing: 8) {
                Text("\(Text("\(strips.count) unused").foregroundStyle(.white).fontWeight(.semibold)) · \(UnusedLabel.text(strips))")
                    .foregroundStyle(Theme.secondaryText)
                    .font(.subheadline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(isOpen ? "Hide" : "Show").font(.subheadline.weight(.semibold)).foregroundStyle(.blue)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.secondaryText.opacity(0.5), style: .init(dash: [4])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // A new row for each state, shown at once: the lazy list would glide the old one in from where it stood.
        .id(isOpen)
        .transition(.identity)
        .accessibilityIdentifier(Self.id)
        .accessibilityLabel(isOpen ? "Hide unused" : "Show unused")
        .accessibilityValue(UnusedLabel.text(strips))
    }
}

extension View {
    /// A list that ends in `UnusedFoldRow` keeps its bottom in place as rows come and go above: Show, Hide, or a strip
    /// coming into use moves the rows above, not the fold row or what's below the change.
    func keepsFoldInPlace() -> some View {
        defaultScrollAnchor(.bottom, for: .sizeChanges)
    }
}

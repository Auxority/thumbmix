import SwiftUI

/// The overview's groups and a strip's tabs: one dark glass bar of equally wide pills along the bottom edge, in
/// thumb reach. Nothing scrolls, so each pill is always one tap in the same place.
struct PillBar<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    /// What the pill shows; `label` is what VoiceOver reads, the full name behind a short one ("Bus" → "Buses").
    let title: KeyPath<Item, String>
    let label: KeyPath<Item, String>

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Pill(title: item[keyPath: title], isSelected: item == selection) { selection = item }
                    .accessibilityLabel(item[keyPath: label])
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(.black), in: Capsule())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // Past xLarge the overview's seven pills would truncate; the bar's height is set by the pills.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

/// Its own view so `height` scales with the bar's capped Dynamic Type size, not the screen's.
private struct Pill: View {
    let title: String
    let isSelected: Bool
    let select: () -> Void
    @ScaledMetric private var height: CGFloat = 44

    var body: some View {
        Button(action: select) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? .black : .white)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(isSelected ? Color.white : .clear, in: Capsule())
                // The 4 pt gap between pills is split between them, so a thumb landing there still picks one.
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

import SwiftUI

/// The overview's groups and a strip's tabs: one dark glass bar of equally wide pills along the bottom edge, in
/// thumb reach. Nothing scrolls, so each pill is always one tap in the same place.
struct PillBar<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    /// What the pill shows; `label` is what VoiceOver reads, the full name behind a short one ("Bus" → "Buses").
    let title: KeyPath<Item, String>
    let label: KeyPath<Item, String>
    @Namespace private var bar

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                // Explicit, so every tap slides alike: a Button's own release animation faded the pill in on some
                // taps only.
                Pill(title: item[keyPath: title], isSelected: item == selection, id: item, bar: bar) {
                    withAnimation(.snappy(duration: 0.2)) { selection = item }
                }
                .accessibilityLabel(item[keyPath: label])
            }
        }
        // One white capsule that follows the open pill, so it slides over solid instead of two crossfading.
        .background { Capsule().fill(.white).matchedGeometryEffect(id: AnyHashable(selection), in: bar, isSource: false) }
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
    let id: AnyHashable
    let bar: Namespace.ID
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
                .matchedGeometryEffect(id: id, in: bar)  // where the bar's white capsule goes when this pill opens
                // The 4 pt gap between pills is split between them, so a thumb landing there still picks one.
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(NoPressDim())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// `.plain` dims a pressed pill and fades it back after release, so how grey the new pill showed depended on how
/// long the finger stayed down. The switch itself is the feedback, as in iOS's own tab bar.
private struct NoPressDim: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

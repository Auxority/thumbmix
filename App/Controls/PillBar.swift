import SwiftUI

/// The overview's groups and a strip's tabs: iOS's own segmented control along the bottom edge, in thumb reach, so a
/// thumb sliding across it carries the system's glass lens (2026-10-29, the user: native over our own). Not a
/// `TabView`: on a 375 pt screen it shows four tabs and hides the rest behind More. Nothing scrolls, so each segment
/// is always one tap in the same place.
struct PillBar<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    /// What the segment shows; `label` is what VoiceOver reads, the full name behind a short one ("Bus" → "Buses").
    let title: KeyPath<Item, String>
    let label: KeyPath<Item, String>

    var body: some View {
        picker(\.title)
            // A segment's own `.accessibilityLabel` held only on some launches ("In" for Inputs, 2026-10-29).
            .accessibilityRepresentation { picker(\.label) }
        // 49 pt, past Apple's 44 pt touch target: 36 pt pills got missed.
        .controlSize(.extraLarge)
        // The control's own track is see-through: the list scrolling under it made the titles hard to read.
        // Behind it, not on it: on the picker itself the glass hid its segments from VoiceOver.
        .background { Color.clear.glassEffect(.regular.tint(.black), in: Capsule()) }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // Past xLarge the overview's seven segments would truncate.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func picker(_ name: KeyPath<Self, KeyPath<Item, String>>) -> some View {
        Picker(selection: $selection) {
            ForEach(items) { Text($0[keyPath: self[keyPath: name]]).tag($0) }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
    }
}

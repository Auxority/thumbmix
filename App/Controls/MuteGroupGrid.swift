import SwiftUI
import ThumbmixCore

/// The desk's six mute groups, two columns above the Main page's pills (I3, 2026-10-19): in reach whatever the list
/// above holds, and away from the strip pages, where a stray tap would silence a whole group.
struct MuteGroupGrid: View {
    let mirror: ConsoleMirror
    let onHold: (Int) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mute groups").sectionLabel().padding(.horizontal, 2)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(1...Catalog.muteGroupCount, id: \.self) { group in
                    MuteGroupButton(group: group, mirror: mirror, onHold: onHold)
                }
            }
        }
    }
}

/// A tap switches the group at once, as the desk's own key does; a hold opens who's in it instead, so a press a bit
/// too slow changes nothing on the desk. A desk group has no name: the button names its strips.
struct MuteGroupButton: View {
    let group: Int
    let mirror: ConsoleMirror
    /// The members screen's header: one wide row, without the hold.
    var wide = false
    var onHold: ((Int) -> Void)?
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let isOn = mirror.isMuteGroupOn(group)
        let names = mirror.muteGroupMemberNames(group)
        label(isOn: isOn == true, names: names)
            .frame(maxWidth: .infinity, minHeight: 56 * sizeScale, alignment: .leading)
            .groupMuteStyle(isOn == true)
            .opacity(names.isEmpty && isOn != true ? Theme.dimmedOpacity : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture { mirror.toggleMuteGroup(group) }
            .onLongPressGesture(minimumDuration: 0.5) { onHold?(group) }
            .dimmedUntilRead(isOn != nil)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("mute-group-\(group)")
            .accessibilityLabel(accessibilityName(names))
            .accessibilityValue(isOn.map { $0 ? Text("On") : Text("Off") } ?? Text(verbatim: ""))
            .accessibilityAction { mirror.toggleMuteGroup(group) }
            .accessibilityAction(named: "Choose strips") { onHold?(group) }
    }

    @ViewBuilder private func label(isOn: Bool, names: [String]) -> some View {
        let caption = names.isEmpty ? String(localized: "empty") : names.joined(separator: " · ")
        if wide {
            HStack {
                Text(isOn ? "Group \(group) · On" : "Group \(group) · Off").font(.headline)
                Spacer(minLength: 8)
                Text("\(names.count) strips").font(.caption)
            }
            .padding(.horizontal, 12)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(group)").font(.headline)
                Text(caption).font(.caption2).lineLimit(1)
            }
            .padding(.horizontal, 12)
        }
    }

    private func accessibilityName(_ names: [String]) -> Text {
        names.isEmpty
            ? Text("Mute group \(group), empty")
            : Text("Mute group \(group): \(names.formatted(.list(type: .and)))")
    }
}

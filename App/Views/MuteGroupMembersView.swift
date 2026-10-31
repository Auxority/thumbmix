import SwiftUI
import ThumbmixCore

/// Who's in a mute group, opened by holding it on the Main page (`mute-groups-i3-v7`, phone 3). Built as a DCA's
/// Members tab: the chip applies at once, the name opens the strip, unused strips that aren't in fold away.
struct MuteGroupMembersView: View {
    let group: Int
    let mirror: ConsoleMirror
    @AppStorage(UnusedFoldRow.muteGroupMembersKey) private var showsUnused = false
    @State private var openStrip: StripID?

    var body: some View {
        ScrollView {
            let unused = mirror.unusedStrips(notIn: .muteGroup(group))
            VStack(spacing: 6) {
                MuteGroupNameRow(group: group, mirror: mirror)
                MuteGroupButton(group: group, mirror: mirror, wide: true)
                MuteGroupNote()
                ForEach(ConsoleMirror.muteGroupAssignableGroups) { stripGroup in
                    let rows = mirror.assignmentRows(stripGroup.strips.filter { showsUnused || !unused.contains($0) })
                    if !rows.isEmpty {
                        Text(stripGroup.title).sectionLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    ForEach(rows) { row in
                        memberRow(row).opacity(unused.contains(row.held) ? 0.45 : 1)
                    }
                }
                if !unused.isEmpty { UnusedFoldRow(strips: unused, isOpen: $showsUnused) }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .keepsFoldInPlace()
        .background(Theme.background)
        // Dimmed as a whole while not live, as the overview's list: the name rows too, not only the chips.
        .disabled(!mirror.isLive)
        .opacity(mirror.isLive ? 1 : 0.4)
        .navigationTitle(title)
        .demoTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $openStrip) { ChannelView(strip: $0, mirror: mirror) }
    }

    private var title: String { String(localized: "Mute group \(group)") }

    private func memberRow(_ row: OverviewItem) -> some View {
        HStack(spacing: 8) {
            Button {
                openStrip = row.opens
            } label: {
                StripNameBlock(
                    title: mirror.title(of: row), caption: mirror.numberCaption(of: row),
                    stripe: ItemStripe(item: row, mirror: mirror), isSoloed: mirror.isSoloed(row) == true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mute-member-" + row.held.id)
            AssignChip(strip: row.held, membership: .muteGroup(group), mirror: mirror)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Joining a group that's on mutes the strip there and then: say so once, above the chips.
private struct MuteGroupNote: View {
    var body: some View {
        Label("While the group is on, a strip you add mutes at once.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .padding(.bottom, 4)
    }
}

#if DEBUG
    #Preview {
        NavigationStack { MuteGroupMembersView(group: 1, mirror: .preview()) }
    }
#endif

import SwiftUI
import ThumbmixCore

/// Every strip a DCA can hold, under its group's heading in desk order (mock 2026-10-17-dca-members, D with I3
/// marks; rows S4 in 2026-10-17-dca-member-stripes). The chip assigns at once, the name opens the strip, as on Fed by. No row moves on a tap; unused strips
/// that aren't assigned fold into the last row.
struct MembersTab: View {
    let dca: Int
    let mirror: ConsoleMirror
    let open: (StripID) -> Void
    @AppStorage(UnusedFoldRow.membersKey) private var showsUnused = false

    var body: some View {
        ScrollView {
            let unused = mirror.unusedStrips(notIn: .dca(dca))
            VStack(spacing: 6) {
                AssignNote()
                ForEach(ConsoleMirror.dcaAssignableGroups) { group in
                    let rows = mirror.assignmentRows(group.strips.filter { showsUnused || !unused.contains($0) })
                    if !rows.isEmpty {
                        Text(group.title).sectionLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    ForEach(rows) { row in
                        memberRow(row).opacity(unused.contains(row.held) ? 0.45 : 1)
                    }
                }
                if !unused.isEmpty { UnusedFoldRow(strips: unused, isOpen: $showsUnused) }
            }
        }
        .keepsFoldInPlace()
    }

    /// Like an overview row (S4, 2026-10-17): the name with the overview's stripe, then the chip where the overview's
    /// mute sits, nearest the thumb.
    private func memberRow(_ row: OverviewItem) -> some View {
        HStack(spacing: 8) {
            Button {
                open(row.opens)
            } label: {
                StripNameBlock(
                    title: mirror.title(of: row), caption: mirror.numberCaption(of: row),
                    stripe: ItemStripe(item: row, mirror: mirror), isSoloed: mirror.isSoloed(row) == true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("member-" + row.held.id)
            AssignChip(strip: row.held, membership: .dca(dca), mirror: mirror)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Joining takes the DCA's fader and mute at once: say so once, above the chips.
private struct AssignNote: View {
    var body: some View {
        Label("An assigned strip follows this DCA's fader and mute at once.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .padding(.bottom, 4)
            .accessibilityIdentifier("assign-note")
    }
}

#if DEBUG
    #Preview {
        MembersTab(dca: 1, mirror: .preview()) { _ in }.padding().background(Theme.background)
    }
#endif

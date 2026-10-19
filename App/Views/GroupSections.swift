import SwiftUI
import ThumbmixCore

/// The strip's DCAs and mute groups (S1, 2026-10-19): set up at soundcheck, never mid-show, so they sit in this draft
/// sheet, not on the Mix tab. Only the sections the strip's kind has.
struct GroupSections: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @Binding var draft: MembershipDraft
    private let dcaColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    private let muteColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        let choices = ConsoleMirror.groupChoices(for: strip)
        if !choices.dcas.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("DCAs")
                LazyVGrid(columns: dcaColumns, spacing: 6) { ForEach(choices.dcas, id: \.self, content: chip) }
            }
        }
        if !choices.muteGroups.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Mute groups")
                LazyVGrid(columns: muteColumns, spacing: 6) { ForEach(choices.muteGroups, id: \.self, content: chip) }
                warning
            }
        }
    }

    private func chip(_ group: Membership) -> some View {
        let current = mirror.assignment(of: strip, to: group)
        return DraftGroupChip(
            title: "\(number(group))", caption: dcaName(group), shown: draft.shown(group, current: current),
            isGroupOn: muteGroupIsOn(group), identifier: identifier(group), label: label(group)
        ) { draft.toggle(group, current: current) }
    }

    private func label(_ group: Membership) -> Text {
        switch group {
        case .dca(let number): Text("DCA \(number), \(dcaName(group) ?? "")")
        case .muteGroup(let number):
            muteGroupIsOn(group) ? Text("Mute group \(number), on") : Text("Mute group \(number)")
        }
    }

    /// Joining a group that's on mutes the strip there and then; Done is the moment, so say so before it.
    @ViewBuilder private var warning: some View {
        let groups = mirror.mutesOnDone(draft, of: strip).map { String(localized: "Group \($0)") }
        if !groups.isEmpty {
            let list = groups.formatted(.list(type: .and))
            let isOn = Text(groups.count == 1 ? "\(list) is on:" : "\(list) are on:")
                .foregroundStyle(Theme.groupMuteText)
            Text("\(isOn) \(mirror.displayName(strip)) mutes when you tap Done.")
                .font(.footnote)
                .accessibilityIdentifier("mutes-on-done")
        }
    }

    private func number(_ group: Membership) -> Int {
        switch group {
        case .dca(let number), .muteGroup(let number): number
        }
    }

    private func dcaName(_ group: Membership) -> String? {
        guard case .dca(let number) = group else { return nil }
        return mirror.name(StripID(.dca, number))
    }

    private func muteGroupIsOn(_ group: Membership) -> Bool {
        guard case .muteGroup(let number) = group else { return false }
        return mirror.isMuteGroupOn(number) == true
    }

    private func identifier(_ group: Membership) -> String {
        switch group {
        case .dca(let number): "sheet-dca-\(number)"
        case .muteGroup(let number): "sheet-mute-\(number)"
        }
    }
}

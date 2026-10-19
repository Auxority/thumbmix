import SwiftUI
import ThumbmixCore

/// The scribble-strip label: name, colour and icon. Edited as a draft and sent together on Done,
/// so the desk's strip doesn't flicker through every keystroke and Cancel leaves the desk untouched.
/// A linked pair keeps a name per side on the desk, and gets one colour and icon written to both.
struct EditStripSheet: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var partnerName: String
    @State private var color: ConsoleColor
    @State private var icon: Int
    /// The DCAs and mute groups ticked here, sent on Done with the name.
    @State private var groups = MembershipDraft()
    private let partner: StripID?

    init(strip: StripID, mirror: ConsoleMirror) {
        self.strip = strip
        self.mirror = mirror
        partner = mirror.isLinked(strip) ? strip.partner : nil
        _name = State(initialValue: mirror.rawName(strip))
        _partnerName = State(initialValue: partner.map(mirror.rawName) ?? "")
        _color = State(initialValue: mirror.color(strip))
        _icon = State(initialValue: mirror.icon(strip).number)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // The icon beside the name, its grid on a page of its own (the user, 2026-10-19), so the
                    // sheet's sections fit one screen.
                    HStack(alignment: .bottom, spacing: 8) {
                        IconTile(icon: icon) { IconPage(selection: $icon) }
                        nameField
                    }
                    if let partner {
                        NameField(
                            title: "Name · \(partner.defaultName)", placeholder: partner.defaultName,
                            name: $partnerName, identifier: "strip-name-partner")
                    }
                    StripColorPicker(color: $color)
                    GroupSections(strip: strip, mirror: mirror, draft: $groups)
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle(partner == nil ? strip.defaultName : strip.pairDefaultName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.buttonStyle(.darkCapsule)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        mirror.edit(strip, name: name, color: color, icon: icon)
                        if let partner { mirror.edit(partner, name: partnerName, color: color, icon: icon) }
                        mirror.apply(groups, to: strip)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .buttonStyle(.darkCapsule)
                    .disabled(!mirror.isLive)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    /// A pair's first field names its odd side; the even side's goes under the icon and this one.
    @ViewBuilder private var nameField: some View {
        if partner != nil {
            NameField(title: "Name · \(strip.defaultName)", placeholder: strip.defaultName, name: $name)
        } else {
            NameField(title: "Name", placeholder: strip.defaultName, name: $name)
        }
    }
}

/// The strip's icon as a square beside the name, with the pencil the strip screen shows next to the name (option A,
/// 2026-10-19). A tap opens the grid; the draft takes the pick, so the desk still sees it only on Done.
private struct IconTile<Page: View>: View {
    let icon: Int
    @ViewBuilder let page: () -> Page

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Icon")
            NavigationLink(destination: page) {
                Image(ConsoleIcon.icon(icon).imageName).resizable().frame(width: 30, height: 30)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottomTrailing) { pencil.offset(x: 6, y: 6) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("icon-tile")
            .accessibilityLabel("Icon")
            .accessibilityValue(ConsoleIcon.icon(icon).name)
        }
    }

    private var pencil: some View {
        Image(systemName: "pencil").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Theme.raised, in: Circle())
            .overlay(Circle().stroke(.black, lineWidth: 2))
    }
}

/// The strip's DCAs and mute groups (S1, 2026-10-19): set up at soundcheck, never mid-show, so they sit in this draft
/// sheet, not on the Mix tab. Only the sections the strip's kind has.
private struct GroupSections: View {
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
            isGroupOn: muteGroupIsOn(group), identifier: identifier(group)
        ) { draft.toggle(group, current: current) }
    }

    /// Joining a group that's on mutes the strip there and then; Done is the moment, so say so before it.
    @ViewBuilder private var warning: some View {
        let groups = mirror.mutesOnDone(draft, of: strip).map { String(localized: "Group \($0)") }
        if !groups.isEmpty {
            let list = groups.formatted(.list(type: .and))
            (Text(groups.count == 1 ? "\(list) is on:" : "\(list) are on:").foregroundStyle(Theme.groupMuteText)
                + Text(" \(mirror.displayName(strip)) mutes when you tap Done."))
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

/// The icon grid on its own page; a pick goes back to the sheet.
private struct IconPage: View {
    @Binding var selection: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            IconPicker(selection: $selection) { dismiss() }.padding(16)
        }
        // Dragging puts the keyboard away, so search results under it can be reached.
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle("Icon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NameField: View {
    let title: LocalizedStringKey
    let placeholder: String
    @Binding var name: String
    var identifier = "strip-name"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title)
            HStack {
                TextField(placeholder, text: $name)
                    .accessibilityIdentifier(identifier)
                    .autocorrectionDisabled()
                    .onChange(of: name) { _, typed in
                        let allowed = StripName.typed(typed)
                        if allowed != typed { name = allowed }
                    }
                Text("\(name.count)/\(StripName.maxLength)").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .padding(12)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct SectionLabel: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText).textCase(.uppercase)
    }
}

/// The desk's 16 colours as on the desk: the eight filled, then the eight inverted (dark, outlined in the colour).
/// Two rows instead of eight and an Inverted switch: one tap picks both, and each swatch looks like what you get
/// (B, 2026-10-17).
private struct StripColorPicker: View {
    @Binding var color: ConsoleColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Colour")
            ForEach([false, true], id: \.self) { inverted in
                HStack(spacing: 6) {
                    ForEach(ConsoleColor.Base.allCases, id: \.self) { base in
                        swatch(ConsoleColor(base: base, inverted: inverted))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func swatch(_ choice: ConsoleColor) -> some View {
        let isSelected = choice == color
        return Button {
            color = choice
        } label: {
            Stripe(choice, cornerRadius: 7)
                .frame(width: 36, height: 36)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: isSelected ? 3 : 0))
        }
        .buttonStyle(.plain)
        .padding(-4)
        .accessibilityIdentifier("color-\(choice.base)" + (choice.inverted ? "-inverted" : ""))
        .accessibilityLabel(Self.name(of: choice.base))
        .accessibilityValue(choice.inverted ? Text("Inverted") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static func name(of base: ConsoleColor.Base) -> LocalizedStringKey {
        switch base {
        case .off: "No colour"
        case .red: "Red"
        case .green: "Green"
        case .yellow: "Yellow"
        case .blue: "Blue"
        case .magenta: "Magenta"
        case .cyan: "Cyan"
        case .white: "White"
        }
    }
}

/// The app's own drawing of each desk icon (`Design/strip-icons`), with the desk's name under it.
private struct IconPicker: View {
    @Binding var selection: Int
    let onPick: () -> Void
    @State private var search = ""
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search icons", text: $search)
                .accessibilityIdentifier("icon-search")
                .autocorrectionDisabled()
                .padding(10)
                .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
            ForEach(matchingGroups) { group in
                Text(group.title).font(.caption).foregroundStyle(Theme.secondaryText)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(group.icons) { icon in tile(icon) }
                }
            }
        }
    }

    private var matchingGroups: [ConsoleIcon.Group] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return ConsoleIcon.groups }
        return ConsoleIcon.groups.compactMap { group in
            let icons = group.icons.filter { $0.name.localizedCaseInsensitiveContains(query) }
            return icons.isEmpty ? nil : ConsoleIcon.Group(title: group.title, icons: icons)
        }
    }

    private func tile(_ icon: ConsoleIcon) -> some View {
        Button {
            selection = icon.number
            onPick()
        } label: {
            VStack(spacing: 2) {
                Image(icon.imageName).resizable().frame(width: 24, height: 24).foregroundStyle(.white)
                    .accessibilityHidden(true)
                Text(icon.name).font(.system(size: 9)).foregroundStyle(Theme.secondaryText).lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white, lineWidth: selection == icon.number ? 2 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("icon-\(icon.number)")
        .accessibilityLabel(icon.name)
        .accessibilityAddTraits(selection == icon.number ? .isSelected : [])
    }
}

#if DEBUG
    #Preview {
        EditStripSheet(strip: StripID(.input, 1), mirror: .preview())
    }
#endif

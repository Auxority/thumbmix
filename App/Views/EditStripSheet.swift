import SwiftUI
import ThumbmixCore

/// The scribble-strip label: name, colour and icon. Edited as a draft and sent together on Done,
/// so the desk's strip doesn't flicker through every keystroke and Cancel leaves the desk untouched.
struct EditStripSheet: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: ConsoleColor
    @State private var icon: Int
    @State private var search = ""

    init(strip: StripID, mirror: ConsoleMirror) {
        self.strip = strip
        self.mirror = mirror
        _name = State(initialValue: mirror.rawName(strip))
        _color = State(initialValue: mirror.color(strip))
        _icon = State(initialValue: mirror.icon(strip).number)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameField
                    StripColorPicker(color: $color)
                    IconPicker(selection: $icon, search: $search)
                }
                .padding(16)
            }
            // Dragging the sheet puts the keyboard away, so search results under it can be reached.
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(strip.defaultName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        mirror.edit(strip, name: name, color: color, icon: icon)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!mirror.isLive)
                }
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Name")
            HStack {
                TextField(strip.defaultName, text: $name)
                    .accessibilityIdentifier("strip-name")
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

/// The desk's eight colours, each also available inverted (lit background, dark text on the strip).
private struct StripColorPicker: View {
    @Binding var color: ConsoleColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Colour")
            HStack(spacing: 6) {
                ForEach(ConsoleColor.Base.allCases, id: \.self) { base in
                    Button {
                        color = ConsoleColor(base: base, inverted: color.inverted)
                    } label: {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Theme.color(ConsoleColor(base: base, inverted: false)))
                            .frame(width: 30, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7).stroke(.white, lineWidth: color.base == base ? 3 : 0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("color-\(base)")
                    .accessibilityLabel(Text(verbatim: "\(base)"))
                }
                Spacer(minLength: 0)
            }
            Toggle("Inverted", isOn: Binding(get: { color.inverted }, set: { color = ConsoleColor(base: color.base, inverted: $0) }))
                .font(.subheadline)
        }
    }
}

/// Emoji stand in for the desk's icon artwork; the desk's own name under each tells shared emoji apart.
private struct IconPicker: View {
    @Binding var selection: Int
    @Binding var search: String
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Icon")
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
        } label: {
            VStack(spacing: 2) {
                Text(icon.emoji).font(.title2)
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

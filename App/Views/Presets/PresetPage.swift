import SwiftUI
import ThumbmixCore

/// One preset at a glance (rounds 4 and 5, 2026-10-28): its name and where it fits, then a card per part it holds,
/// each its picture beside a few values; a card opens every value. The parts to load are chips above Load, pinned at
/// the bottom with Save a copy or Remove.
struct PresetPage: View {
    @State var entry: LibraryEntry
    let strip: StripID
    let mirror: ConsoleMirror
    let library: PresetLibrary
    @Environment(\.dismiss) private var dismiss
    /// Shared with each part's page, so a part left out there stays out here.
    @State private var choice = LoadChoice()
    @State private var isRenaming = false
    @State private var isEditingWords = false
    @State private var isConfirmingRemove = false
    @State private var newName = ""
    @State private var shared: SharedPreset?
    @State private var notice: String?

    private var preset: Preset { entry.preset }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                ForEach(preset.parts) { part in
                    NavigationLink {
                        PresetPartPage(preset: preset, part: part, mirror: mirror) { loadBar(withSecondary: false) }
                    } label: {
                        PresetCard(preset: preset, part: part, mirror: mirror)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .presetPage(mirror)
        .navigationTitle(preset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Share", systemImage: "square.and.arrow.up") { share() }.accessibilityIdentifier("preset-share")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { loadBar(withSecondary: true) }
        .sheet(isPresented: $isEditingWords) { MatchWordsSheet(entry: $entry, library: library) }
        .sheet(item: $shared) { ShareSheet(url: $0.url) }
        .alert("Rename preset", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { rename() }
        }
        .alert("Remove “\(preset.name)”?", isPresented: $isConfirmingRemove) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { remove() }
        } message: {
            Text("The file is deleted from this iPhone.")
        }
        .noticeAlert($notice)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(verbatim: preset.name).font(.title2.bold())
                if entry.isOwn {
                    Button("Rename", systemImage: "pencil") {
                        newName = preset.name
                        isRenaming = true
                    }
                    .labelStyle(.iconOnly).accessibilityIdentifier("preset-rename")
                }
            }
            // Verbatim: a source's name comes from its index, never read as markup.
            Text(verbatim: [origin, fits].joined(separator: " · ")).font(.subheadline)
                .foregroundStyle(Theme.secondaryText).accessibilityIdentifier("preset-fits")
            if entry.isOwn {
                Button("Edit match words") { isEditingWords = true }.font(.subheadline)
                    .accessibilityIdentifier("preset-edit-words")
            }
        }
        .padding(.vertical, 4)
    }

    private var origin: String {
        guard let source = entry.source else { return String(localized: "On this iPhone") }
        return String(localized: "From \(library.title(of: source)) · read-only")
    }

    /// The strips on this desk whose names fit, or the words a name would need.
    private var fits: String {
        let strips = mirror.fittingStrips(preset)
        guard strips.isEmpty else {
            let names = strips.map { "\(mirror.name($0)) (\($0.defaultName))" }.joined(separator: ", ")
            return String(localized: "fits \(names)")
        }
        guard !preset.matchWords.isEmpty else { return String(localized: "fits no strip on this desk") }
        return String(localized: "fits strips named \(preset.matchWords.formatted(.list(type: .or)))")
    }

    private func loadBar(withSecondary: Bool) -> some View {
        PresetLoadBar(preset: preset, strip: strip, mirror: mirror, choice: choice) {
            if withSecondary { secondaryAction }
        }
    }

    @ViewBuilder private var secondaryAction: some View {
        if entry.isOwn {
            Button("Remove preset", role: .destructive) { isConfirmingRemove = true }
                .buttonStyle(.wideDarkCapsule)
        } else {
            Button("Save a copy") { saveCopy() }.buttonStyle(.wideDarkCapsule)
        }
    }

    private func share() {
        do {
            shared = SharedPreset(url: try library.exportFile(preset))
        } catch {
            notice = error.localizedDescription
        }
    }

    private func rename() {
        var renamed = preset
        renamed.name = newName.trimmingCharacters(in: .whitespaces)
        do {
            entry = try library.replace(entry, with: renamed)
        } catch {
            notice = error.localizedDescription
        }
    }

    /// A source's preset changes only as a copy On this iPhone.
    private func saveCopy() {
        do {
            let copy = try library.save(preset)
            notice = String(localized: "Saved “\(copy.preset.name)” to this iPhone.")
        } catch {
            notice = error.localizedDescription
        }
    }

    private func remove() {
        do {
            try library.remove(entry)
            dismiss()
        } catch {
            notice = error.localizedDescription
        }
    }
}

/// The words a strip's name is matched against: tap × to drop one, type to add one.
private struct MatchWordsSheet: View {
    @Binding var entry: LibraryEntry
    let library: PresetLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var words: [String]
    @State private var typed = ""
    @State private var notice: String?

    init(entry: Binding<LibraryEntry>, library: PresetLibrary) {
        _entry = entry
        self.library = library
        _words = State(initialValue: entry.wrappedValue.preset.matchWords)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                        HStack {
                            Text(verbatim: word)
                            Spacer()
                            Button("Remove \(word)", systemImage: "xmark.circle.fill") { words.removeAll { $0 == word } }
                                .labelStyle(.iconOnly).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    HStack {
                        TextField("New word", text: $typed).accessibilityIdentifier("preset-new-word").onSubmit(add)
                        Button("Add", action: add)
                    }
                } footer: {
                    Text("A strip fits when its name contains one of these words, whatever the case.")
                }
                .listRowBackground(Theme.track)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Match words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.buttonStyle(.darkCapsule) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }.fontWeight(.bold).buttonStyle(.darkCapsule)
                        .accessibilityIdentifier("preset-words-done")
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .noticeAlert($notice)
        }
    }

    private func add() {
        let word = typed.trimmingCharacters(in: .whitespaces)
        if !word.isEmpty, !words.contains(word) { words.append(word) }
        typed = ""
    }

    private func save() {
        add()
        var changed = entry.preset
        changed.matchWords = words
        do {
            entry = try library.replace(entry, with: changed)
            dismiss()
        } catch {
            notice = error.localizedDescription
        }
    }
}

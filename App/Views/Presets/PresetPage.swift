import SwiftUI
import ThumbmixCore

/// One preset as a Settings-style list (option 2, 2026-10-28): the name, which strips it fits, then a section per part
/// it holds. Load and Remove sit pinned at the bottom.
struct PresetPage: View {
    @State var entry: LibraryEntry
    let strip: StripID
    let mirror: ConsoleMirror
    let library: PresetLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var isRenaming = false
    @State private var isEditingWords = false
    @State private var isConfirmingRemove = false
    @State private var newName = ""
    @State private var shared: SharedPreset?
    @State private var notice: String?

    private var preset: Preset { entry.preset }

    var body: some View {
        List {
            header
            fits
            ForEach(preset.parts) { part in section(part) }
        }
        .presetPage(mirror)
        .navigationTitle(preset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Share", systemImage: "square.and.arrow.up") { share() }.accessibilityIdentifier("preset-share")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .sheet(isPresented: $isLoading) { LoadPresetSheet(preset: preset, strip: strip, mirror: mirror) }
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
        Section {
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
            if let source = entry.source {
                // Verbatim: the name comes from the source's index, never read as markup.
                Text(verbatim: String(localized: "From \(library.title(of: source)) · read-only"))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .listRowBackground(Color.clear)
    }

    private var fits: some View {
        let strips = mirror.fittingStrips(preset)
        return Section("Fits") {
            if strips.isEmpty {
                Text("No strip on this desk is named like this.").foregroundStyle(Theme.secondaryText)
            } else {
                Text(verbatim: strips.map { "\(mirror.name($0)) (\($0.defaultName))" }.joined(separator: ", "))
                    .accessibilityIdentifier("preset-fits")
            }
            if !preset.matchWords.isEmpty {
                Text("Strips named \(preset.matchWords.formatted(.list(type: .or)))").font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            if entry.isOwn {
                Button("Edit match words") { isEditingWords = true }.accessibilityIdentifier("preset-edit-words")
            }
        }
        .listRowBackground(Theme.track)
    }

    private func section(_ part: PresetPart) -> some View {
        Section(part.title) {
            if part == .eq, let curve = PresetSummary.eqCurve(preset) { PresetEQCurve(bands: curve.bands, lowCut: curve.lowCut) }
            ForEach(PresetSummary.rows(preset, part)) { row in
                LabeledContent(row.label) { Text(verbatim: row.value) }
            }
        }
        .listRowBackground(Theme.track)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button("Load onto \(mirror.name(strip))…") { isLoading = true }
                .buttonStyle(.wideProminentDarkCapsule)
                .disabled(!mirror.isLive).accessibilityIdentifier("preset-load")
            if entry.isOwn {
                Button("Remove preset", role: .destructive) { isConfirmingRemove = true }
            } else {
                Button("Save a copy") { saveCopy() }
            }
        }
        .padding(16)
        .background(Theme.background)
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

/// The EQ curve of a preset, read-only: the same grid and axis as the EQ tab's graph, the low cut in yellow.
private struct PresetEQCurve: View {
    let bands: [EQBandState]
    let lowCut: LowCutState?

    var body: some View {
        Canvas { context, size in
            EQGraphGrid.draw(in: context, size: size)
            context.stroke(EQGraphGrid.curve(bands, lowCut, in: size), with: .color(.white), lineWidth: 2)
            if let lowCut {
                context.stroke(
                    EQGraphGrid.curve(bands, lowCut, in: size, upTo: lowCut.frequency * 2), with: .color(EQGraph.lowCutColor),
                    lineWidth: 3)
            }
        }
        .frame(height: 140)
        .accessibilityHidden(true)
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

import SwiftUI
import ThumbmixCore

/// One preset as a Settings-style list (option 2, 2026-10-28): the name and where it came from, which strips it
/// fits, then a section per part it holds. Load and Save a copy / Remove sit pinned at the bottom.
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
    private var isOwn: Bool { entry.source.isWritable }

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
            Button("Rename") { Task { await rename() } }
        }
        .alert("Remove “\(preset.name)”?", isPresented: $isConfirmingRemove) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { Task { await remove() } }
        } message: {
            Text("The file is deleted from this iPhone.")
        }
        .noticeAlert($notice)
    }

    private var header: some View {
        Section {
            HStack {
                Text(verbatim: preset.name).font(.title2.bold())
                if isOwn {
                    Button("Rename", systemImage: "pencil") {
                        newName = preset.name
                        isRenaming = true
                    }
                    .labelStyle(.iconOnly).accessibilityIdentifier("preset-rename")
                }
            }
            Text(verbatim: sourceLine).font(.subheadline).foregroundStyle(Theme.secondaryText)
        }
        .listRowBackground(Color.clear)
    }

    private var sourceLine: String {
        let name = library.title(of: entry.source)
        return isOwn ? name : String(localized: "From \(name) · read-only")
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
            if isOwn {
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
            if isOwn {
                Button("Remove preset", role: .destructive) { isConfirmingRemove = true }
            } else {
                Button("Save a copy") { Task { await saveCopy() } }.accessibilityIdentifier("preset-copy")
            }
        }
        .padding(16)
        .background(Theme.background)
    }

    private func share() {
        do {
            shared = SharedPreset(url: try library.exportFile(preset))
        } catch {
            notice = presetErrorText(error)
        }
    }

    private func rename() async {
        var renamed = preset
        renamed.name = newName.trimmingCharacters(in: .whitespaces)
        do {
            entry = try await library.replace(entry, with: renamed)
        } catch {
            notice = presetErrorText(error)
        }
    }

    private func remove() async {
        do {
            try await library.remove(entry)
            dismiss()
        } catch {
            notice = presetErrorText(error)
        }
    }

    private func saveCopy() async {
        do {
            let copy = try await library.save(preset)
            notice = String(localized: "Saved “\(copy.preset.name)” on this iPhone.")
        } catch {
            notice = presetErrorText(error)
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
            context.stroke(curve(in: size, upTo: 20_000, lowCut: lowCut), with: .color(.white), lineWidth: 2)
            if let lowCut {
                context.stroke(
                    curve(in: size, upTo: lowCut.frequency * 2, lowCut: lowCut), with: .color(EQGraph.lowCutColor),
                    lineWidth: 3)
            }
        }
        .frame(height: 140)
        .accessibilityHidden(true)
    }

    private func curve(in size: CGSize, upTo maxHertz: Double, lowCut: LowCutState?) -> Path {
        var path = Path()
        let lastX = min(EQAxis.position(hertz: maxHertz), 1)
        for step in 0...120 {
            let x = Double(step) / 120 * lastX
            let decibels = EQReading.decibels(at: EQAxis.hertz(at: x), bands: bands, lowCut: lowCut)
            let point = CGPoint(x: x * size.width, y: EQGraphGrid.y(decibels: decibels) * size.height)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
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
                    ForEach(words, id: \.self) { word in
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
                    Button("Done") { Task { await save() } }.fontWeight(.bold).buttonStyle(.darkCapsule)
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

    private func save() async {
        add()
        var changed = entry.preset
        changed.matchWords = words
        do {
            entry = try await library.replace(entry, with: changed)
            dismiss()
        } catch {
            notice = presetErrorText(error)
        }
    }
}

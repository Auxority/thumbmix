import SwiftUI
import ThumbmixCore
import UniformTypeIdentifiers

/// The edit sheet's Presets row: how many presets fit the strip's name, pushing the page.
struct PresetsRow: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @Environment(\.presetLibrary) private var library

    var body: some View {
        NavigationLink {
            PresetsPage(strip: strip, mirror: mirror)
        } label: {
            HStack {
                Text("Presets").font(.headline)
                Spacer()
                if let summary { Text(verbatim: summary).foregroundStyle(Theme.secondaryText) }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("presets-row")
        // The page works without a desk; only loading and saving need one.
        .environment(\.isEnabled, true)
    }

    /// "2 fit “Kick”": nothing when none fits.
    private var summary: String? {
        let name = mirror.rawName(strip)
        guard let library, !name.isEmpty else { return nil }
        let fitting = (library.own + library.builtIn).filter { PresetMatching.fits($0.preset, name: name) }.count
        return fitting == 0 ? nil : String(localized: "\(fitting) fit “\(name)”")
    }
}

/// The engineer's presets and the built-in ones: those fitting the strip's name first, then the others.
struct PresetsPage: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @Environment(\.presetLibrary) private var library

    var body: some View {
        if let library { PresetsList(strip: strip, mirror: mirror, library: library) }
    }
}

private struct PresetsList: View {
    let strip: StripID
    let mirror: ConsoleMirror
    let library: PresetLibrary
    @State private var isSaving = false
    @State private var isImporting = false
    @State private var notice: String?

    var body: some View {
        let (fits, others) = library.ordered { PresetMatching.fits($0, name: mirror.rawName(strip)) }
        List {
            if !fits.isEmpty { section(String(localized: "Fits “\(mirror.name(strip))”"), fits) }
            if !others.isEmpty { section(String(localized: "Others"), others) }
            if fits.isEmpty && others.isEmpty {
                Text("No presets yet. Save this strip as one, or import a file.").foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Theme.track)
            }
            Section {
                Button("Save this strip as a preset…") { isSaving = true }
                    .disabled(!mirror.isLive).accessibilityIdentifier("presets-save")
                Button("Import a preset file…") { isImporting = true }
            } footer: {
                if !library.skipped.isEmpty { Text(verbatim: skippedText) }
            }
            .listRowBackground(Theme.track)
        }
        .presetPage(mirror)
        .navigationTitle("Presets")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: mirror.isLive) { open() }
        .refreshable { library.refresh() }
        .sheet(isPresented: $isSaving) { SavePresetSheet(strip: strip, mirror: mirror, library: library) }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            importFile(result)
        }
        .noticeAlert($notice)
    }

    private func section(_ title: String, _ entries: [LibraryEntry]) -> some View {
        Section(title) {
            ForEach(entries) { entry in
                NavigationLink {
                    PresetPage(entry: entry, strip: strip, mirror: mirror, library: library)
                } label: {
                    PresetListRow(entry: entry)
                }
                .accessibilityIdentifier("preset-row-" + entry.preset.name)
            }
        }
        .listRowBackground(Theme.track)
    }

    /// Reads every tab of the strip, so the load and save sheets find their values read, and the files again, so an
    /// edit made in Files shows up.
    private func open() {
        for tab in ChannelTab.presetTabs(for: strip.kind) { mirror.read(tab, of: strip) }
        library.refresh()
    }

    /// Files in the Presets folder the app doesn't take, each with why: whoever edited one in Files can fix it.
    private var skippedText: String {
        library.skipped.map { "\($0.file): \($0.reason)" }.joined(separator: "\n")
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let opened = url.startAccessingSecurityScopedResource()
            defer { if opened { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= PresetValidation.maxBytes else { throw PresetError.tooLarge }
            let entry = try library.importPreset(Data(contentsOf: url))
            notice = String(localized: "Imported “\(entry.preset.name)” to this iPhone.")
        } catch {
            notice = error.localizedDescription
        }
    }
}

private struct PresetListRow: View {
    let entry: LibraryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: entry.preset.name).font(.headline)
            Text(verbatim: entry.preset.parts.map(\.title).joined(separator: " · "))
                .font(.subheadline).foregroundStyle(Theme.secondaryText)
            Text(entry.isOwn ? "On this iPhone" : "Built-in").font(.footnote).foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 2)
    }
}

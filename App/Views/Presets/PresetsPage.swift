import SwiftUI
import ThumbmixCore

/// The edit sheet's Presets row: how many presets fit the strip's name, pushing the page.
struct PresetsRow: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// The sheet's, so a load can close the presets and every page on top of them at once.
    @Binding var isOpen: Bool
    @Environment(\.presetLibrary) private var library

    var body: some View {
        Button {
            isOpen = true
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
        .navigationDestination(isPresented: $isOpen) { PresetsPage(strip: strip, mirror: mirror) }
        .accessibilityIdentifier("presets-row")
        // The page works without a desk; only loading and saving need one.
        .environment(\.isEnabled, true)
    }

    /// "2 fit “Kick”": nothing when none fits.
    private var summary: String? {
        let name = mirror.rawName(strip)
        guard let library, !name.isEmpty else { return nil }
        let fitting = library.entries.filter { PresetMatching.fits($0.preset, name: name) }.count
        return fitting == 0 ? nil : String(localized: "\(fitting) fit “\(name)”")
    }
}

/// The presets on this iPhone: those fitting the strip's name first, then the others.
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

    var body: some View {
        let (fits, others) = library.ordered { PresetMatching.fits($0, name: mirror.rawName(strip)) }
        List {
            if !fits.isEmpty { section(String(localized: "Fits “\(mirror.name(strip))”"), fits) }
            if !others.isEmpty { section(String(localized: "Others"), others) }
            if fits.isEmpty && others.isEmpty {
                Text("No presets yet. Save this strip as one, or add a source.").foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Theme.track)
            }
            Section {
                Button("Save this strip as a preset…") { isSaving = true }
                    .disabled(!mirror.isLive).accessibilityIdentifier("presets-save")
            } footer: {
                if !library.skipped.isEmpty { Text(verbatim: skippedText) }
            }
            .listRowBackground(Theme.track)
        }
        .presetPage(mirror)
        .navigationTitle("Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink("Sources") { SourcesPage(library: library, mirror: mirror) }
                    .accessibilityIdentifier("presets-sources")
            }
        }
        .task(id: mirror.isLive) { await open() }
        .refreshable {
            library.refresh()
            await library.refreshSources()
        }
        .sheet(isPresented: $isSaving) { SavePresetSheet(strip: strip, mirror: mirror, library: library) }
    }

    private func section(_ title: String, _ entries: [LibraryEntry]) -> some View {
        Section(title) {
            ForEach(entries) { entry in
                NavigationLink {
                    PresetPage(entry: entry, strip: strip, mirror: mirror, library: library)
                } label: {
                    PresetListRow(entry: entry, source: entry.source.map(library.title(of:)))
                }
                .accessibilityIdentifier("preset-row-" + entry.preset.name)
            }
        }
        .listRowBackground(Theme.track)
    }

    /// Reads every tab of the strip, so the load and save sheets find their values read, and the presets again, so an
    /// edit made in Files or on the web shows up.
    private func open() async {
        for tab in ChannelTab.presetTabs(for: strip.kind) { mirror.read(tab, of: strip) }
        library.refresh()
        await library.refreshSources()
    }

    /// Files in the Presets folder the app doesn't take, each with why: whoever edited one in Files can fix it.
    private var skippedText: String {
        library.skipped.map { "\($0.file): \($0.reason)" }.joined(separator: "\n")
    }
}

private struct PresetListRow: View {
    let entry: LibraryEntry
    /// The web source's name; nil On this iPhone.
    let source: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: entry.preset.name).font(.headline)
            Text(verbatim: ([source].compactMap { $0 } + entry.preset.parts.map(\.title)).joined(separator: " · "))
                .font(.subheadline).foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 2)
    }
}

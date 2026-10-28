import SwiftUI
import ThumbmixCore
import UniformTypeIdentifiers

/// Where presets come from: each source with how its last read went, and a way to add or remove one.
struct SourcesPage: View {
    let library: PresetLibrary
    let mirror: ConsoleMirror
    /// What the picker was opened for, set before it opens: the completion can run after the sheet's own state reset.
    @State private var pick = Pick.folder
    @State private var isPicking = false
    @State private var isAskingForAddress = false
    @State private var address = ""
    @State private var notice: String?

    private enum Pick: Identifiable {
        case folder, file
        var id: Self { self }
        var types: [UTType] { self == .folder ? [.folder] : [.json] }
    }

    var body: some View {
        List {
            Section {
                ForEach(library.sources) { source in
                    SourceRow(source: source, library: library)
                        .swipeActions { if source.isRemovable { removeButton(source) } }
                }
            } footer: {
                Text("Presets from these sources are read again each time you open the list. Swipe to remove one.")
            }
            .listRowBackground(Theme.track)
            if !library.hasThumbmixSource {
                Section {
                    Button("Add the Thumbmix source") {
                        library.addThumbmixSource()
                        Task { await library.refresh() }
                    }
                }
                .listRowBackground(Theme.track)
            }
        }
        .presetPage(mirror)
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Add", systemImage: "plus") {
                    Button("Folder…", systemImage: "folder") { open(.folder) }
                    Button("File…", systemImage: "doc") { open(.file) }
                    Button("Web address…", systemImage: "network") { isAskingForAddress = true }
                }
                .accessibilityIdentifier("sources-add")
            }
        }
        .refreshable { await library.refresh() }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: pick.types) { result in
            add(result, as: pick)
        }
        .alert("Add a web address", isPresented: $isAskingForAddress) {
            TextField("https://…/index.json", text: $address).textInputAutocapitalization(.never).keyboardType(.URL)
            Button("Cancel", role: .cancel) { address = "" }
            Button("Add") { addAddress() }
        } message: {
            Text("An https:// address of a Thumbmix source's index.json.")
        }
        .noticeAlert($notice)
    }

    private func removeButton(_ source: PresetSource) -> some View {
        Button("Remove", role: .destructive) { library.remove(source) }
    }

    private func open(_ kind: Pick) {
        pick = kind
        isPicking = true
    }

    private func add(_ result: Result<URL, Error>, as pick: Pick) {
        do {
            let url = try result.get()
            if pick == .folder { try library.addFolder(url) } else { try library.addFile(url) }
            Task { await library.refresh() }
        } catch {
            notice = presetErrorText(error)
        }
    }

    private func addAddress() {
        defer { address = "" }
        do {
            try library.addWebAddress(address)
            Task { await library.refresh() }
        } catch {
            notice = presetErrorText(error)
        }
    }
}

private struct SourceRow: View {
    let source: PresetSource
    let library: PresetLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: library.title(of: source)).font(.headline)
            if source.kind != .onThisIPhone {
                Text(verbatim: source.kindName).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            if let result = library.results[source.id] {
                Text(verbatim: status(result)).font(.footnote).foregroundStyle(color(result))
                ForEach(Array(result.skipped.enumerated()), id: \.offset) { _, skipped in
                    Text(verbatim: "\(skipped.file): \(skipped.reason)").font(.footnote).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("source-" + source.name)
    }

    private func status(_ result: SourceResult) -> String {
        switch result.status {
        case .ok: String(localized: "^[\(result.presets.count) preset](inflect: true)")
        case .cached(let why): String(localized: "Showing the last read: \(why)")
        case .failed(let why): why
        }
    }

    private func color(_ result: SourceResult) -> Color {
        result.status == .ok ? .green : .orange
    }
}

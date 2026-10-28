import SwiftUI
import ThumbmixCore

/// Where presets come from: On this iPhone, then each web source with how its last read went, and a way to add or
/// remove one.
struct SourcesPage: View {
    let library: PresetLibrary
    let mirror: ConsoleMirror
    @State private var isAskingForAddress = false
    @State private var address = ""
    @State private var notice: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text("On this iPhone").font(.headline)
                    Text("^[\(library.own.count) preset](inflect: true)").font(.footnote).foregroundStyle(.green)
                }
                ForEach(library.sources) { source in
                    SourceRow(source: source, library: library)
                        .swipeActions { Button("Remove", role: .destructive) { library.removeSource(source) } }
                }
            } footer: {
                Text("Web sources are read again each time you open the presets, and kept for use offline. Swipe to remove one.")
            }
            .listRowBackground(Theme.track)
            if library.lacksDefaultSource {
                Section {
                    Button("Add the Thumbmix source") {
                        let added = library.addDefaultSources()
                        Task { await library.refreshSources(added) }
                    }
                    .accessibilityIdentifier("sources-add-default")
                }
                .listRowBackground(Theme.track)
            }
        }
        .presetPage(mirror)
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") { isAskingForAddress = true }.accessibilityIdentifier("sources-add")
            }
        }
        .refreshable { await library.refreshSources() }
        .alert("Add a web source", isPresented: $isAskingForAddress) {
            TextField("https://…/index.json", text: $address).textInputAutocapitalization(.never).keyboardType(.URL)
            Button("Cancel", role: .cancel) { address = "" }
            Button("Add") { addAddress() }
        } message: {
            Text("The https:// address of a Thumbmix source's index.json.")
        }
        .noticeAlert($notice)
    }

    private func addAddress() {
        defer { address = "" }
        do {
            let added = try library.addSource(address)
            Task { await library.refreshSources([added]) }
        } catch {
            notice = error.localizedDescription
        }
    }
}

private struct SourceRow: View {
    let source: PresetSource
    let library: PresetLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: library.title(of: source.id)).font(.headline)
            if let address = source.webAddress {
                // Shown as text, never as a link: the address came from whoever runs the source.
                Text(verbatim: address.absoluteString).font(.subheadline).foregroundStyle(Theme.secondaryText).lineLimit(1)
            }
            if let result = library.results[source] {
                Text(verbatim: status(result)).font(.footnote).foregroundStyle(result.status == .ok ? .green : .orange)
                ForEach(result.skipped, id: \.file) { skipped in
                    Text(verbatim: "\(skipped.file): \(skipped.reason)").font(.footnote).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("source-" + (source.webAddress?.host ?? source.id))
    }

    private func status(_ result: SourceResult) -> String {
        switch result.status {
        case .ok: String(localized: "^[\(result.presets.count) preset](inflect: true)")
        case .cached(let why): String(localized: "Showing the last good read: \(why)")
        case .failed(let why): why
        }
    }
}

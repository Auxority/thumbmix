import SwiftUI
import ThumbmixCore
import UniformTypeIdentifiers

/// Where presets come from: On this iPhone, then each source with how its last read went. Add sits pinned at the
/// bottom, in thumb reach (pick C, 2026-10-28); swipe a source to remove it.
struct SourcesPage: View {
    let library: PresetLibrary
    let mirror: ConsoleMirror
    @State private var isAskingForAddress = false
    @State private var address = ""
    @State private var picking: PickedKind?
    @State private var notice: String?

    var body: some View {
        List {
            Section {
                SourceLabel(icon: "iphone", title: Text("On this iPhone")) {
                    Text("^[\(library.own.count) preset](inflect: true)").font(.footnote).foregroundStyle(.green)
                }
                ForEach(library.sources) { source in
                    SourceRow(source: source, library: library)
                        .swipeActions { Button("Remove", role: .destructive) { library.removeSource(source) } }
                }
            } footer: {
                Text("Sources are read again each time you open the presets, and kept for use offline. Swipe to remove one.")
            }
            .listRowBackground(Theme.track)
        }
        .presetPage(mirror)
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { addMenu }
        .refreshable { await library.refreshSources() }
        .fileImporter(
            isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
            allowedContentTypes: picking == .file ? [.json] : [.folder]
        ) { result in
            add(result)
        }
        .alert("Add a web source", isPresented: $isAskingForAddress) {
            TextField("https://…/index.json", text: $address).textInputAutocapitalization(.never).keyboardType(.URL)
            Button("Cancel", role: .cancel) { address = "" }
            Button("Add") { addAddress() }
        } message: {
            Text("The https:// address of a Thumbmix source's index.json.")
        }
        .noticeAlert($notice)
    }

    /// Opens upward from the bottom edge; `.fixed` keeps Folder on top, as listed.
    private var addMenu: some View {
        Menu {
            Button("Folder…", systemImage: "folder") { picking = .folder }.accessibilityIdentifier("sources-add-folder")
            Button("File…", systemImage: "doc") { picking = .file }.accessibilityIdentifier("sources-add-file")
            Button("Web address…", systemImage: "globe") { isAskingForAddress = true }
                .accessibilityIdentifier("sources-add-web")
        } label: {
            Label("Add a source", systemImage: "plus").fontWeight(.semibold)
        }
        .menuOrder(.fixed)
        .buttonStyle(.wideProminentDarkCapsule)
        .accessibilityIdentifier("sources-add")
        .padding(16)
        .background(Theme.background)
    }

    /// The bookmark is made here, while the picker's URL still grants access. `picking` is already cleared by now
    /// (the importer closes first), so Core tells a folder from a file by the item itself.
    private func add(_ result: Result<URL, Error>) {
        do {
            let added = try library.addPicked(try result.get())
            Task { await library.refreshSources([added]) }
        } catch {
            notice = error.localizedDescription
        }
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

private enum PickedKind { case folder, file }

/// A source's kind as an icon beside its name, and what's known about it under that.
private struct SourceLabel<Detail: View>: View {
    let icon: String
    let title: Text
    @ViewBuilder let detail: Detail

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.body).foregroundStyle(Theme.secondaryText).frame(width: 28, height: 28)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 7)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                title.font(.headline)
                detail
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SourceRow: View {
    let source: PresetSource
    let library: PresetLibrary

    var body: some View {
        // Verbatim: a web source names itself in its index, and a folder's name is the engineer's.
        SourceLabel(icon: icon, title: Text(verbatim: library.title(of: source.id))) {
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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("source-" + (source.webAddress?.host ?? source.id))
    }

    private var icon: String {
        switch source.kind {
        case .web: "globe"
        case .folder: "folder"
        case .file: "doc"
        }
    }

    private func status(_ result: SourceResult) -> String {
        switch result.status {
        // `String(localized:)` would leave "^[4 preset](inflect: true)" as it is: only an attributed string inflects.
        case .ok: String(AttributedString(localized: "^[\(result.presets.count) preset](inflect: true)").characters)
        case .cached(let why): String(localized: "Showing the last good read: \(why)")
        case .failed(let why): why
        }
    }
}

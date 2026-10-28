import Foundation
import os

/// The sources of the library: which are listed (kept across launches by `PresetSources`) and their last reads.
extension PresetLibrary {
    private static let log = Logger(subsystem: "thumbmix", category: "presets")

    /// Reads `only` these sources, or every one, at once, each result shown as it arrives: one that never answers holds
    /// nothing up. A source already being read is left to that read, so two never race for its offline copy.
    public func refreshSources(_ only: [PresetSource]? = nil) async {
        guard let web else { return }
        let due = (only ?? sources).filter { !reading.contains($0) }
        reading.formUnion(due)
        await withTaskGroup(of: (PresetSource, SourceResult).self) { group in
            for source in due { group.addTask { (source, await web.read(source)) } }
            for await (source, result) in group {
                reading.remove(source)
                take(result, of: source, web)
            }
        }
    }

    /// A cancelled read (the page went, the desk link blipped) is no news about the source; a source removed meanwhile
    /// loses the offline copy its read just wrote.
    private func take(_ result: SourceResult, of source: PresetSource, _ web: PresetSources) {
        guard sources.contains(source) else { return web.forgetCache(of: source) }
        guard !Task.isCancelled else { return }
        results[source] = result
        if let fresh = result.freshBookmark, let index = sources.firstIndex(of: source) {
            sources[index] = sources[index].withBookmark(fresh)
            persist()
        }
        if case .failed(let reason) = result.status {
            Self.log.notice("source \(source.id, privacy: .private) failed: \(reason, privacy: .public)")
        }
    }

    /// A web source's name from its index, or its host until it was read; a folder's or file's name as picked.
    public func title(of id: PresetSource.ID) -> String {
        guard let source = sources.first(where: { $0.id == id }) else { return id }
        if let title = results[source]?.title { return title }
        return source.name ?? source.webAddress?.host ?? id
    }

    /// Only HTTPS, with no name, password or query. The same address twice is one source.
    @discardableResult
    public func addSource(_ text: String) throws -> PresetSource {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), PresetSources.isAcceptable(url)
        else { throw SourceError.refusedAddress }
        let source = PresetSource.web(url)
        if !sources.contains(source) { add(source) }
        return source
    }

    /// A folder or file picked in Files, by what the item is: the picker's callback can't say which button opened it.
    /// Call it inside the callback, while the URL still grants access. One picked before is that source, kept by the
    /// new bookmark, which also mends a source whose old bookmark went stale.
    @discardableResult
    public func addPicked(_ url: URL) throws -> PresetSource {
        let picked = try BookmarkAccess.isFolder(url) ? PresetSource.folder(url) : PresetSource.file(url)
        guard let index = sources.firstIndex(where: { $0.isPicked(url) }) else {
            add(picked)
            return picked
        }
        sources[index] = PresetSource(kind: picked.kind, name: picked.name, id: sources[index].id)
        persist()
        return sources[index]
    }

    /// Its presets go with it, and its offline copy too.
    public func removeSource(_ source: PresetSource) {
        sources.removeAll { $0 == source }
        results[source] = nil
        web?.forgetCache(of: source)
        persist()
    }

    private func add(_ source: PresetSource) {
        sources.append(source)
        persist()
    }

    private func persist() {
        do {
            try web?.save(sources)
        } catch {
            Self.log.error("saving the sources failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

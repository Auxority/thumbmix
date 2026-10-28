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

    /// The engineer removed the Thumbmix source: the Sources page offers it back.
    public var lacksDefaultSource: Bool { !(web?.defaults ?? []).map(PresetSource.web).allSatisfy(sources.contains) }

    /// The defaults it added, to be read.
    @discardableResult
    public func addDefaultSources() -> [PresetSource] {
        let added = (web?.defaults ?? []).map(PresetSource.web).filter { !sources.contains($0) }
        sources += added
        persist()
        return added
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

    /// A folder picked in Files: call it inside the picker's callback, while the URL still grants access. One picked
    /// before is that source.
    @discardableResult
    public func addFolder(_ url: URL) throws -> PresetSource {
        if let picked = sources.first(where: { $0.isPicked(url) }) { return picked }
        let source = try PresetSource.folder(url)
        add(source)
        return source
    }

    /// A single preset file picked in Files, as `addFolder`.
    @discardableResult
    public func addFile(_ url: URL) throws -> PresetSource {
        if let picked = sources.first(where: { $0.isPicked(url) }) { return picked }
        let source = try PresetSource.file(url)
        add(source)
        return source
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

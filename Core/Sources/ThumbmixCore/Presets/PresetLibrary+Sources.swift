import Foundation
import os

/// The web sources of the library: which are listed (kept across launches by `PresetSources`) and their last reads.
extension PresetLibrary {
    private static let log = Logger(subsystem: "thumbmix", category: "presets")

    /// Reads every source at once, each result shown as it arrives: one that never answers holds nothing up. A source
    /// removed meanwhile gets no result.
    public func refreshSources() async {
        guard let web else { return }
        await withTaskGroup(of: (URL, SourceResult).self) { group in
            for source in sources { group.addTask { (source, await web.read(source)) } }
            for await (source, result) in group where sources.contains(source) {
                results[source] = result
                if case .failed(let reason) = result.status {
                    Self.log.notice("source \(source.host ?? "", privacy: .private) failed: \(reason, privacy: .public)")
                }
            }
        }
    }

    /// The name the source's index gives itself, or its host until it was read.
    public func title(of source: URL) -> String { results[source]?.title ?? source.host ?? source.absoluteString }

    /// The engineer removed the Thumbmix source: the Sources page offers it back.
    public var lacksDefaultSource: Bool { !(web?.defaults ?? []).allSatisfy(sources.contains) }

    public func addDefaultSources() {
        for source in web?.defaults ?? [] where !sources.contains(source) { sources.append(source) }
        persist()
    }

    /// Only HTTPS, with no name, password or query. The same address twice is one source.
    @discardableResult
    public func addSource(_ text: String) throws -> URL {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), PresetSources.isAcceptable(url)
        else { throw SourceError.refusedAddress }
        if !sources.contains(url) {
            sources.append(url)
            persist()
        }
        return url
    }

    /// Its presets go with it, and its offline copy too.
    public func removeSource(_ source: URL) {
        sources.removeAll { $0 == source }
        results[source] = nil
        web?.forgetCache(of: source)
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

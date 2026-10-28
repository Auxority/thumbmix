import CryptoKit
import Foundation

public enum SourceStatus: Equatable, Sendable {
    case ok
    /// The source could not be read now; these are the presets of its last good read.
    case cached(String)
    case failed(String)
}

/// One read of a source: its presets, the files it holds or lists that the app refused, and how the read went.
public struct SourceResult: Equatable, Sendable {
    public var presets: [LibraryEntry] = []
    public var skipped: [SkippedFile] = []
    public var status: SourceStatus = .ok
    /// The name a web source's index gives itself.
    public var title: String?
    /// A folder's or file's new bookmark, when the one it had was stale: the library keeps it.
    var freshBookmark: Data?

    static func failed(_ reason: String) -> SourceResult { SourceResult(status: .failed(reason)) }
}

/// The sources the engineer added: web ones as in SideStore (an HTTPS index that lists preset files), and folders and
/// files picked in Files (`PresetFiles`). The list and each source's last good read live in one folder in Application
/// Support, not Caches: the offline copy must still be there at the show, after iOS cleared its caches.
public struct PresetSources: Sendable {
    /// The repo's `presets/` folder: present on first launch and removable. The README gives its address, to add again
    /// like any web source.
    public static let thumbmix = URL(string: "https://raw.githubusercontent.com/Auxority/thumbmix/main/presets/index.json")!
    static let maxPresets = 200

    let folder: URL
    /// The sources of a first launch, before the engineer added or removed one.
    let defaults: [URL]
    let session: URLSession
    /// How long a whole read may take, however many requests it makes.
    let deadline: Duration

    public init(
        folder: URL, defaults: [URL] = [thumbmix], session: URLSession = .shared, deadline: Duration = .seconds(30)
    ) {
        self.folder = folder
        self.defaults = defaults
        self.session = session
        self.deadline = deadline
    }

    // MARK: The list

    private var listFile: URL { folder.appendingPathComponent("sources.json") }

    /// A missing list is a first launch; after that the list decides, so a removed default stays removed. A list of
    /// addresses (0.57) is read as web sources.
    func load() -> [PresetSource] {
        guard let data = try? Data(contentsOf: listFile) else { return defaults.map(PresetSource.web) }
        let saved =
            (try? JSONDecoder().decode([PresetSource].self, from: data))
            ?? (try? JSONDecoder().decode([URL].self, from: data))?.map(PresetSource.web)
        guard let saved else { return defaults.map(PresetSource.web) }
        return saved.filter { $0.webAddress.map(Self.isAcceptable) ?? true }
    }

    func save(_ sources: [PresetSource]) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(sources).write(to: listFile, options: .atomic)
    }

    // MARK: Reading

    /// Every kind keeps its last good read: a file lost to the network, to iCloud or to a moved folder shows its copy
    /// rather than leaving the list mid-show, and stays named in `skipped`.
    public func read(_ source: PresetSource) async -> SourceResult {
        switch source.kind {
        case .web(let url): await readWeb(url, id: source.id)
        case .folder(let bookmark): readLocal(source, PresetFiles.read(bookmark, of: source, PresetFiles.readFolder))
        case .file(let bookmark): readLocal(source, PresetFiles.read(bookmark, of: source, PresetFiles.readFile))
        }
    }

    /// Reads the index and every preset it lists. A bad index, or an address that can't be read, gives the last good
    /// read; a bad preset is skipped and named.
    private func readWeb(_ address: URL, id: String) async -> SourceResult {
        do {
            let fetched = try await withDeadline { try await fetchSource(address) }
            // A cancelled read only lost its files to the cancel: the copy stays as it was.
            try Task.checkCancellation()
            return merge(fetched, into: id).result
        } catch {
            return fromCache(id, because: error.localizedDescription)
        }
    }

    /// A folder or file read in place. One the bookmark no longer opens gives the last good read; one that lost a
    /// file keeps its copy and says why, since the engineer can't tell a kept copy from a fresh read otherwise.
    private func readLocal(_ source: PresetSource, _ fetched: Fetched?) -> SourceResult {
        guard let fetched else { return fromCache(source.id, because: PresetFiles.notFoundText) }
        var (result, kept) = merge(fetched, into: source.id)
        if !kept.isEmpty, let why = result.skipped.first(where: { fetched.lost.contains($0.file) })?.reason {
            result.status = .cached(why)
        }
        return result
    }

    /// A lost file (not one refused) keeps its copy from the last good read; what was read replaces the rest.
    private func merge(_ fetched: Fetched, into id: String) -> (result: SourceResult, kept: [CachedFile]) {
        let cache = cacheFile(for: id)
        var result = fetched.result
        let kept = readCache(cache).files.filter { fetched.lost.contains($0.file) }
        result.presets += entries(kept, of: id)
        writeCache(Cache(title: result.title, files: fetched.files + kept), to: cache)
        return (result, kept)
    }

    /// The whole read, not only each request: a server dripping bytes would otherwise hold the Presets list for as
    /// long as it likes (a request's own timeout only fires when nothing arrives).
    private func withDeadline<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: deadline)
                throw SourceError.unreachable(CoreStrings.text("it took too long"))
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw SourceError.notASource }
            return first
        }
    }

    // MARK: The last good read

    struct CachedFile: Codable {
        let file: String
        let data: Data
    }

    private struct Cache: Codable {
        /// The index's name, so a source read offline keeps it.
        var title: String?
        var files: [CachedFile] = []
    }

    /// Named by a hash: an address can hold anything a file name can't. A web source's id is its address, so its copy
    /// from before folder sources keeps its name.
    private func cacheFile(for id: String) -> URL {
        let hash = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent("cache-\(hash).json")
    }

    /// A removed source's last good read goes with it: one added again starts from nothing.
    func forgetCache(of source: PresetSource) {
        try? FileManager.default.removeItem(at: cacheFile(for: source.id))
    }

    private func writeCache(_ cached: Cache, to cache: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? JSONEncoder().encode(cached).write(to: cache, options: .atomic)
    }

    private func readCache(_ cache: URL) -> Cache {
        (try? Data(contentsOf: cache)).flatMap { try? JSONDecoder().decode(Cache.self, from: $0) } ?? Cache()
    }

    /// Checked again like a new file: the cache is the app's own copy, but a damaged one is not trusted either.
    private func entries(_ files: [CachedFile], of id: String) -> [LibraryEntry] {
        files.compactMap { file in
            (try? PresetValidation.decode(file.data)).map { LibraryEntry(source: id, file: file.file, preset: $0) }
        }
    }

    private func fromCache(_ id: String, because reason: String) -> SourceResult {
        let cached = readCache(cacheFile(for: id))
        let presets = entries(cached.files, of: id)
        return presets.isEmpty
            ? .failed(reason) : SourceResult(presets: presets, status: .cached(reason), title: cached.title)
    }
}

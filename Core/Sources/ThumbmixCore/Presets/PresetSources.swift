import CryptoKit
import Foundation

public enum SourceStatus: Equatable, Sendable {
    case ok
    /// The source could not be read now; these are the presets of its last good read.
    case cached(String)
    case failed(String)
}

/// One read of a web source: its presets, the files it lists that the app refused, and how the read went.
public struct SourceResult: Equatable, Sendable {
    public var presets: [LibraryEntry] = []
    public var skipped: [SkippedFile] = []
    public var status: SourceStatus = .ok
    /// The name the source's index gives itself.
    public var title: String?

    static func failed(_ reason: String) -> SourceResult { SourceResult(status: .failed(reason)) }
}

/// The web sources the engineer added, as in SideStore: an HTTPS index that lists preset files. The list and each
/// source's last good read live in one folder in Application Support, not Caches: the offline copy must still be there
/// at the show, after iOS cleared its caches.
public struct PresetSources: Sendable {
    /// The repo's `presets/` folder: present on first launch, removable, and added back from the Sources page.
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

    /// A missing list is a first launch; after that the list decides, so a removed default stays removed.
    func load() -> [URL] {
        guard let data = try? Data(contentsOf: listFile), let saved = try? JSONDecoder().decode([URL].self, from: data)
        else { return defaults }
        return saved.filter(Self.isAcceptable)
    }

    func save(_ sources: [URL]) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(sources).write(to: listFile, options: .atomic)
    }

    // MARK: Reading

    /// Reads the index and every preset it lists. A bad index, or an address that can't be read, gives the last good
    /// read; a bad preset is skipped and named.
    public func read(_ source: URL) async -> SourceResult {
        let cache = cacheFile(for: source)
        do {
            let fetched = try await withDeadline { try await fetchSource(source) }
            // A file lost to the network keeps its copy from the last good read: a flaky read must not empty the cache.
            let kept = readCache(cache).filter { fetched.lost.contains($0.file) }
            writeCache(fetched.files + kept, to: cache)
            return fetched.result
        } catch {
            return fromCache(source, because: error.localizedDescription)
        }
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

    private struct Cache: Codable { let files: [CachedFile] }

    /// Named by a hash: an address can hold anything a file name can't.
    private func cacheFile(for source: URL) -> URL {
        let hash = SHA256.hash(data: Data(source.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent("cache-\(hash).json")
    }

    /// A removed source's last good read goes with it: one added again starts from nothing.
    func forgetCache(of source: URL) {
        try? FileManager.default.removeItem(at: cacheFile(for: source))
    }

    private func writeCache(_ files: [CachedFile], to cache: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? JSONEncoder().encode(Cache(files: files)).write(to: cache, options: .atomic)
    }

    private func readCache(_ cache: URL) -> [CachedFile] {
        (try? Data(contentsOf: cache)).flatMap { try? JSONDecoder().decode(Cache.self, from: $0) }?.files ?? []
    }

    /// Checked again like a new file: the cache is the app's own copy, but a damaged one is not trusted either.
    private func fromCache(_ source: URL, because reason: String) -> SourceResult {
        let presets = readCache(cacheFile(for: source)).compactMap { file in
            (try? PresetValidation.decode(file.data)).map { LibraryEntry(source: source, file: file.file, preset: $0) }
        }
        return presets.isEmpty ? .failed(reason) : SourceResult(presets: presets, status: .cached(reason))
    }
}

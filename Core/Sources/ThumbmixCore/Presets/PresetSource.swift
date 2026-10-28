import Foundation

/// A source of read-only presets: a web index, or a folder or file picked in Files and kept by its bookmark.
public struct PresetSource: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: Codable, Hashable, Sendable {
        /// An HTTPS address of an index (`PresetIndex`) that lists preset files.
        case web(URL)
        /// Every `.json` in it is a preset, read again each time.
        case folder(bookmark: Data)
        case file(bookmark: Data)
    }

    public let kind: Kind
    /// A folder's or file's name as picked; nil for a web source, whose index names it.
    public let name: String?
    /// A web source's address, so one address twice is one source and its offline copy keeps its name.
    public let id: String

    init(kind: Kind, name: String?, id: String) {
        self.kind = kind
        self.name = name
        self.id = id
    }

    public static func web(_ url: URL) -> PresetSource { PresetSource(kind: .web(url), name: nil, id: url.absoluteString) }

    /// From the URL a Files picker gave, while it still grants access (inside the picker's callback).
    public static func folder(_ url: URL) throws -> PresetSource {
        PresetSource(kind: .folder(bookmark: try BookmarkAccess.bookmark(for: url)), name: url.lastPathComponent, id: newID())
    }

    public static func file(_ url: URL) throws -> PresetSource {
        PresetSource(kind: .file(bookmark: try BookmarkAccess.bookmark(for: url)), name: url.lastPathComponent, id: newID())
    }

    private static func newID() -> String { "picked-" + UUID().uuidString }

    /// The same source, kept by a fresh bookmark: its id, and with it its offline copy and status, stay.
    func withBookmark(_ bookmark: Data) -> PresetSource {
        switch kind {
        case .web: self
        case .folder: PresetSource(kind: .folder(bookmark: bookmark), name: name, id: id)
        case .file: PresetSource(kind: .file(bookmark: bookmark), name: name, id: id)
        }
    }

    /// One source by its id: a refreshed bookmark is still the source the list, its result and its copy know.
    public static func == (lhs: PresetSource, rhs: PresetSource) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    public var webAddress: URL? {
        if case .web(let url) = kind { return url }
        return nil
    }

    /// Whether this source is the folder or file at `url`, so a second pick of it adds nothing.
    func isPicked(_ url: URL) -> Bool {
        switch kind {
        case .web: false
        case .folder(let bookmark), .file(let bookmark): BookmarkAccess.path(of: bookmark) == BookmarkAccess.path(of: url)
        }
    }
}

/// Security-scoped bookmarks for folders and files picked in Files. An iOS picker's URL carries the access, and a
/// bookmark made from it with no options keeps it across launches; macOS (the tests) wants `.withSecurityScope`.
enum BookmarkAccess {
    #if os(macOS)
        private static let creation: URL.BookmarkCreationOptions = [.withSecurityScope]
        private static let resolution: URL.BookmarkResolutionOptions = [.withSecurityScope]
    #else
        private static let creation: URL.BookmarkCreationOptions = []
        private static let resolution: URL.BookmarkResolutionOptions = []
    #endif

    static func bookmark(for url: URL) throws -> Data {
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        return try url.bookmarkData(options: creation, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// What was picked, from the item itself: the picker's URL may or may not end in "/" for a folder.
    static func isFolder(_ url: URL) -> Bool {
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? url.hasDirectoryPath
    }

    /// Where a URL or bookmark points, spelled one way: the picker may give one folder as "/a/b" and "/private/a/b/".
    static func path(of url: URL) -> String { url.resolvingSymlinksInPath().standardizedFileURL.path }

    static func path(of bookmark: Data) -> String? {
        var stale = false
        let url = try? URL(resolvingBookmarkData: bookmark, options: resolution, relativeTo: nil, bookmarkDataIsStale: &stale)
        return url.map(path(of:))
    }

    /// Access is held only while `body` runs: an unbalanced start leaks kernel resources. `fresh` is a new bookmark
    /// when this one was stale (the item moved): it still opens the item, and the new one keeps opening it.
    static func withAccess<T>(_ bookmark: Data, _ body: (URL) -> T) throws -> (value: T, fresh: Data?) {
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: resolution, relativeTo: nil, bookmarkDataIsStale: &stale)
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        // Checked inside the access: the sandbox may refuse even a look at another provider's item without it.
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        let fresh = stale ? try? url.bookmarkData(options: creation, includingResourceValuesForKeys: nil, relativeTo: nil) : nil
        return (body(url), fresh)
    }
}

/// Folder and file sources: read in place each time, so an edit made in Files shows. A file that can't be read now (iCloud
/// hasn't downloaded it, the disk said no) is lost, not refused: `PresetSources` keeps its last good copy.
enum PresetFiles {
    typealias Fetched = PresetSources.Fetched

    static var notFoundText: String { CoreStrings.text("Not found. Pick it again.") }
    static var stillDownloadingText: String { CoreStrings.text("Still downloading from iCloud. Refresh in a moment.") }

    /// A file iCloud keeps elsewhere: a coordinated read would wait for the download, offline for good.
    struct StillDownloading: LocalizedError {
        var errorDescription: String? { PresetFiles.stillDownloadingText }
    }

    /// nil when the bookmark no longer opens the folder or file.
    static func read(_ bookmark: Data, of source: PresetSource, _ read: (URL, String) -> Fetched?) -> Fetched? {
        guard let opened = try? BookmarkAccess.withAccess(bookmark, { read($0, source.id) }), var fetched = opened.value
        else { return nil }
        fetched.result.freshBookmark = opened.fresh
        return fetched
    }

    /// One file: a refused one fails the source with its reason.
    static func readFile(_ url: URL, source: String) -> Fetched? {
        var fetched = Fetched(result: SourceResult())
        take(url.lastPathComponent, at: url, of: source, into: &fetched)
        if let skipped = fetched.result.skipped.first {
            fetched.result.status = .failed(skipped.reason)
            if fetched.lost.isEmpty { fetched.result.skipped = [] }
        }
        return fetched
    }

    static func readFolder(_ folder: URL, source: String) -> Fetched? {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return nil }
        var fetched = Fetched(result: SourceResult())
        let files = names.filter { $0.lowercased().hasSuffix(".json") && !$0.hasPrefix(".") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        for name in files {
            guard fetched.result.presets.count + fetched.result.skipped.count < PresetSources.maxPresets else {
                fetched.result.skipped.append(SkippedFile(file: name, reason: CoreStrings.text("More than 200 files.")))
                continue
            }
            take(name, at: folder.appendingPathComponent(name), of: source, into: &fetched)
        }
        let placeholders = iCloudPlaceholders(in: names, folder)
        fetched.result.skipped += placeholders
        fetched.lost.formUnion(placeholders.map(\.file))
        return fetched
    }

    private static func take(_ name: String, at url: URL, of source: String, into fetched: inout Fetched) {
        do {
            let data = try data(at: url)
            fetched.result.presets.append(LibraryEntry(source: source, file: name, preset: try PresetValidation.decode(data)))
            fetched.files.append(PresetSources.CachedFile(file: name, data: data))
        } catch {
            fetched.result.skipped.append(SkippedFile(file: name, reason: error.localizedDescription))
            if !(error is PresetError) { fetched.lost.insert(name) }
        }
    }

    /// A file iCloud Drive hasn't downloaded shows as ".name.json.icloud": ask for it now, it is there on the next read.
    private static func iCloudPlaceholders(in names: [String], _ folder: URL) -> [SkippedFile] {
        names.filter { $0.hasPrefix(".") && $0.lowercased().hasSuffix(".json.icloud") }.sorted().map { placeholder in
            let real = String(placeholder.dropFirst().dropLast(".icloud".count))
            // The real item's URL, not the placeholder's: the placeholder is only how the folder lists it.
            try? FileManager.default.startDownloadingUbiquitousItem(at: folder.appendingPathComponent(real))
            return SkippedFile(file: real, reason: stillDownloadingText)
        }
    }

    static func preset(at url: URL) throws -> Preset { try PresetValidation.decode(data(at: url)) }

    /// The size is checked before the file is read: a huge file never fills memory.
    private static func data(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        if values.isUbiquitousItem == true, values.ubiquitousItemDownloadingStatus != .current {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            throw StillDownloading()
        }
        guard values.fileSize ?? 0 <= PresetValidation.maxBytes else { throw PresetError.tooLarge }
        return try coordinatedData(url)
    }

    /// Coordinated, so a file iCloud keeps elsewhere is downloaded first and one being written is read whole.
    private static func coordinatedData(_ url: URL) throws -> Data {
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
            result = Result { try Data(contentsOf: readable) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }
}

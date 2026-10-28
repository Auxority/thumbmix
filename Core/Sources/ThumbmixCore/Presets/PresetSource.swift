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

    public var webAddress: URL? {
        if case .web(let url) = kind { return url }
        return nil
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

    /// Access is held only while `body` runs: an unbalanced start leaks kernel resources.
    static func withAccess<T>(_ bookmark: Data, _ body: (URL) -> T) throws -> T {
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: resolution, relativeTo: nil, bookmarkDataIsStale: &stale)
        // A stale bookmark means the item moved or the access lapsed: the engineer picks it again.
        guard !stale, FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        return body(url)
    }
}

/// Folder and file sources: read in place each time, so an edit made in Files shows. They keep no offline copy: the
/// files are on the iPhone already, or iCloud downloads them.
enum PresetFiles {
    static var notFoundText: String { CoreStrings.text("Not found. Pick it again.") }

    static func read(_ bookmark: Data, of source: PresetSource, _ read: (URL, String) -> SourceResult) -> SourceResult {
        do {
            return try BookmarkAccess.withAccess(bookmark) { read($0, source.id) }
        } catch {
            return .failed(notFoundText)
        }
    }

    static func readFile(_ url: URL, source: String) -> SourceResult {
        do {
            return SourceResult(presets: [LibraryEntry(source: source, file: url.lastPathComponent, preset: try preset(at: url))])
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static func readFolder(_ folder: URL, source: String) -> SourceResult {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return .failed(notFoundText) }
        var result = SourceResult()
        let files = names.filter { $0.lowercased().hasSuffix(".json") && !$0.hasPrefix(".") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        for name in files {
            guard result.presets.count + result.skipped.count < PresetSources.maxPresets else {
                result.skipped.append(SkippedFile(file: name, reason: CoreStrings.text("More than 200 files.")))
                continue
            }
            do {
                let preset = try preset(at: folder.appendingPathComponent(name))
                result.presets.append(LibraryEntry(source: source, file: name, preset: preset))
            } catch {
                result.skipped.append(SkippedFile(file: name, reason: error.localizedDescription))
            }
        }
        result.skipped += iCloudPlaceholders(in: names, folder)
        return result
    }

    /// A file iCloud Drive hasn't downloaded shows as ".name.json.icloud": ask for it now, it is there on the next read.
    private static func iCloudPlaceholders(in names: [String], _ folder: URL) -> [SkippedFile] {
        names.filter { $0.hasPrefix(".") && $0.lowercased().hasSuffix(".json.icloud") }.sorted().map { placeholder in
            try? FileManager.default.startDownloadingUbiquitousItem(at: folder.appendingPathComponent(placeholder))
            let real = String(placeholder.dropFirst().dropLast(".icloud".count))
            return SkippedFile(file: real, reason: CoreStrings.text("Still downloading from iCloud. Refresh in a moment."))
        }
    }

    /// The size is checked before the file is read: a huge file never fills memory.
    static func preset(at url: URL) throws -> Preset {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= PresetValidation.maxBytes else { throw PresetError.tooLarge }
        return try PresetValidation.decode(coordinatedData(url))
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

import Foundation

public struct SourcedPreset: Identifiable, Equatable, Sendable {
    public let preset: Preset
    /// The file name, or the path in a source's index: what names a preset within its source.
    public let file: String
    public var id: String { file }
}

public struct SkippedFile: Equatable, Sendable {
    public let file: String
    public let reason: String
}

public enum SourceStatus: Equatable, Sendable {
    case ok
    /// The source could not be read now; these are the presets of its last good read.
    case cached(String)
    case failed(String)

    public static let notFoundText = CoreStrings.text("Not found. Pick it again.")
}

public struct SourceResult: Equatable, Sendable {
    public var presets: [SourcedPreset] = []
    public var skipped: [SkippedFile] = []
    public var status: SourceStatus = .ok
    /// The name a web source's index gives itself.
    public var title: String?

    static func failed(_ reason: String) -> SourceResult { SourceResult(status: .failed(reason)) }
}

/// Reads a source into validated presets. Every preset passes `PresetValidation`, whatever the source: a bad one is
/// skipped and named, and the rest still loads.
public struct SourceReader: Sendable {
    static let maxPresets = 200

    let session: URLSession
    let cacheDirectory: URL
    /// Where On this iPhone keeps its files.
    let ownFolder: URL?
    /// How long a whole web read may take, however many requests it makes.
    let deadline: Duration

    public init(
        session: URLSession = .shared, cacheDirectory: URL, ownFolder: URL? = nil, deadline: Duration = .seconds(30)
    ) {
        self.session = session
        self.cacheDirectory = cacheDirectory
        self.ownFolder = ownFolder
        self.deadline = deadline
    }

    /// Forgets a removed source's last good read: a source added again starts from nothing.
    func forgetCache(of source: PresetSource) {
        try? FileManager.default.removeItem(at: cacheFile(for: source))
    }

    public func read(_ source: PresetSource) async -> SourceResult {
        switch source.kind {
        case .onThisIPhone:
            guard let ownFolder else { return .failed(SourceStatus.notFoundText) }
            return readFolder(ownFolder)
        case .folder(let bookmark): return readBookmarked(bookmark, readFolder)
        case .file(let bookmark): return readBookmarked(bookmark, readFile)
        case .url(let url): return await readWeb(url, cache: cacheFile(for: source))
        }
    }

    private func readBookmarked(_ bookmark: Data, _ read: (URL) -> SourceResult) -> SourceResult {
        do {
            return try BookmarkAccess.withAccess(bookmark, read)
        } catch {
            return .failed(SourceStatus.notFoundText)
        }
    }

    // MARK: Local files

    private func readFile(_ url: URL) -> SourceResult {
        do {
            let preset = try Self.preset(at: url)
            return SourceResult(presets: [SourcedPreset(preset: preset, file: url.lastPathComponent)])
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func readFolder(_ folder: URL) -> SourceResult {
        guard
            let names = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil, options: []
            ).map(\.lastPathComponent)
        else { return .failed(SourceStatus.notFoundText) }
        var result = SourceResult()
        let jsonFiles = names.filter { $0.lowercased().hasSuffix(".json") && !$0.hasPrefix(".") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        for name in jsonFiles {
            guard result.presets.count + result.skipped.count < Self.maxPresets else {
                result.skipped.append(SkippedFile(file: name, reason: CoreStrings.text("More than 200 files.")))
                continue
            }
            do {
                let preset = try Self.preset(at: folder.appendingPathComponent(name))
                result.presets.append(SourcedPreset(preset: preset, file: name))
            } catch {
                result.skipped.append(SkippedFile(file: name, reason: error.localizedDescription))
            }
        }
        result.skipped += iCloudPlaceholders(in: names, folder)
        return result
    }

    /// A file iCloud Drive hasn't downloaded shows as ".name.json.icloud": ask for it now, it is there on the next read.
    private func iCloudPlaceholders(in names: [String], _ folder: URL) -> [SkippedFile] {
        names.filter { $0.hasPrefix(".") && $0.hasSuffix(".json.icloud") }.map { placeholder in
            try? FileManager.default.startDownloadingUbiquitousItem(at: folder.appendingPathComponent(placeholder))
            let real = String(placeholder.dropFirst().dropLast(".icloud".count))
            return SkippedFile(file: real, reason: CoreStrings.text("Still downloading from iCloud. Refresh in a moment."))
        }
    }

    /// The size is checked before the file is read: a huge file never fills memory.
    private static func preset(at url: URL) throws -> Preset {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= PresetValidation.maxBytes else { throw PresetError.tooLarge }
        return try PresetValidation.decode(coordinatedData(url))
    }

    /// Coordinated, so a file iCloud keeps elsewhere is downloaded first.
    private static func coordinatedData(_ url: URL) throws -> Data {
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
            result = Result { try Data(contentsOf: readable) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    func cacheFile(for source: PresetSource) -> URL {
        cacheDirectory.appendingPathComponent("source-\(source.id.uuidString).json")
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

    /// Made while the picked URL is still accessible (`withAccess` on the picker's URL, or inside its callback).
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
        if stale { throw CocoaError(.fileNoSuchFile) }
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        return body(url)
    }
}

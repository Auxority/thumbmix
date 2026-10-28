import Foundation
import Observation
import os

/// A preset as listed: where it came from and its file within that source.
public struct LibraryEntry: Identifiable, Equatable, Sendable {
    public let source: PresetSource
    public let file: String
    public let preset: Preset
    public var id: String { source.id.uuidString + "/" + file }

    public init(source: PresetSource, file: String, preset: Preset) {
        self.source = source
        self.file = file
        self.preset = preset
    }
}

public enum LibraryError: Error, Equatable, Sendable {
    /// Only presets On this iPhone can be changed or removed; "Save a copy" brings one here.
    case readOnly
}

/// Every source and the presets last read from each. Sources other than On this iPhone are read again whenever the
/// Presets page opens, so edits made in Files or on the web show up; each keeps its last good read for offline use.
@MainActor @Observable
public final class PresetLibrary {
    public private(set) var sources: [PresetSource]
    public private(set) var results: [UUID: SourceResult] = [:]
    public var isRefreshing: Bool { refreshes > 0 }

    private var refreshes = 0
    /// Counts the reads of On this iPhone: only the newest may set its result, so an older read can't undo a save.
    @ObservationIgnored private var ownReads = 0
    @ObservationIgnored private let store: PresetSourceStore
    @ObservationIgnored private let reader: SourceReader
    @ObservationIgnored private let ownFolder: URL
    @ObservationIgnored private let log = Logger(subsystem: "thumbmix", category: "presets")

    /// `includesDefaultSource` is false in UI tests: no network there.
    public init(
        supportDirectory: URL, ownFolder: URL, cacheDirectory: URL, session: URLSession = .shared,
        includesDefaultSource: Bool = true, webDeadline: Duration = .seconds(30)
    ) {
        store = PresetSourceStore(
            file: supportDirectory.appendingPathComponent("sources.json"), includesDefaultSource: includesDefaultSource)
        reader = SourceReader(
            session: session, cacheDirectory: cacheDirectory, ownFolder: ownFolder, deadline: webDeadline)
        self.ownFolder = ownFolder
        sources = store.load()
    }

    // MARK: Reading

    /// Reads every source at once, each result shown as it arrives: On this iPhone first, so a web source that never
    /// answers holds nothing up. One that fails keeps its place with its reason.
    public func refresh() async {
        refreshes += 1
        defer { refreshes -= 1 }
        let reader = reader
        await refreshOwn()
        await withTaskGroup(of: (PresetSource, SourceResult).self) { group in
            for source in sources where source.isRemovable { group.addTask { (source, await reader.read(source)) } }
            for await (source, result) in group where sources.contains(where: { $0.id == source.id }) {
                results[source.id] = result
                if case .failed(let reason) = result.status {
                    log.notice("source \(source.id, privacy: .public): \(reason, privacy: .public)")
                }
            }
        }
    }

    /// Every preset of every source, in the order of the sources.
    public var entries: [LibraryEntry] {
        sources.flatMap { source in
            (results[source.id]?.presets ?? []).map { LibraryEntry(source: source, file: $0.file, preset: $0.preset) }
        }
    }

    /// The presets whose match words fit first, then the others, each by name.
    public func ordered(fitting fits: (Preset) -> Bool) -> (fits: [LibraryEntry], others: [LibraryEntry]) {
        let sorted = entries.sorted { $0.preset.name.localizedStandardCompare($1.preset.name) == .orderedAscending }
        return (sorted.filter { fits($0.preset) }, sorted.filter { !fits($0.preset) })
    }

    public func title(of source: PresetSource) -> String { results[source.id]?.title ?? source.name }

    // MARK: Sources

    public var hasThumbmixSource: Bool { sources.contains { $0.id == PresetSource.thumbmix.id } }

    public func addThumbmixSource() {
        guard !hasThumbmixSource else { return }
        sources.append(.thumbmix)
        persist()
    }

    public func addFolder(_ url: URL) throws {
        try add(PresetSource(name: url.lastPathComponent, kind: .folder(bookmark: try BookmarkAccess.bookmark(for: url))))
    }

    public func addFile(_ url: URL) throws {
        try add(PresetSource(name: url.lastPathComponent, kind: .file(bookmark: try BookmarkAccess.bookmark(for: url))))
    }

    /// Only HTTPS, with no name, password or query. The same address twice is one source.
    public func addWebAddress(_ text: String) throws {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), SourceReader.isAcceptable(url)
        else { throw SourceError.refusedAddress }
        guard !sources.contains(where: { $0.kind == .url(url) }) else { return }
        try add(PresetSource(name: url.host ?? url.absoluteString, kind: .url(url)))
    }

    public func remove(_ source: PresetSource) {
        guard source.isRemovable else { return }
        sources.removeAll { $0.id == source.id }
        results[source.id] = nil
        reader.forgetCache(of: source)
        persist()
    }

    private func add(_ source: PresetSource) throws {
        sources.append(source)
        persist()
    }

    private func persist() {
        do {
            try store.save(sources)
        } catch {
            log.error("saving the sources failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Own presets

    /// Writes a preset into On this iPhone as `<name>.json`. A name already taken gets " 2", " 3"... and the preset
    /// carries that name too. Saving the copy of a preset from another source is saving it.
    @discardableResult
    public func save(_ preset: Preset) async throws -> LibraryEntry {
        try PresetValidation.validate(preset)
        var named = preset
        let file = uniqueFile(for: &named.name)
        try write(named, to: file)
        await refreshOwn()
        return LibraryEntry(source: .onThisIPhone, file: file, preset: named)
    }

    /// A changed preset replaces the old file; a changed name moves it.
    @discardableResult
    public func replace(_ entry: LibraryEntry, with preset: Preset) async throws -> LibraryEntry {
        guard entry.source.isWritable else { throw LibraryError.readOnly }
        try PresetValidation.validate(preset)
        var renamed = preset
        let file = preset.name == entry.preset.name ? entry.file : uniqueFile(for: &renamed.name, except: entry.file)
        try write(renamed, to: entry.file)
        // A move, not a second file: on a case-insensitive disk "kick" and "Kick" are one file, which a write and a
        // delete would remove.
        if file != entry.file {
            try FileManager.default.moveItem(
                at: ownFolder.appendingPathComponent(entry.file), to: ownFolder.appendingPathComponent(file))
        }
        await refreshOwn()
        return LibraryEntry(source: entry.source, file: file, preset: renamed)
    }

    public func remove(_ entry: LibraryEntry) async throws {
        guard entry.source.isWritable else { throw LibraryError.readOnly }
        try FileManager.default.removeItem(at: ownFolder.appendingPathComponent(entry.file))
        await refreshOwn()
    }

    /// A file received by AirDrop or Mail is copied here: iOS gives it no lasting place of its own. Stored as checked
    /// as any other, and never asking anything: asking happens on loading.
    @discardableResult
    public func importPreset(_ data: Data) async throws -> LibraryEntry {
        try await save(PresetValidation.decode(data))
    }

    /// The preset as a `.json` file under its name, in a folder of its own in the temporary directory.
    public func exportFile(_ preset: Preset) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(Self.fileName(for: preset.name))
        try PresetJSON.encode(preset).write(to: url, options: .atomic)
        return url
    }

    private func refreshOwn() async {
        ownReads += 1
        let mine = ownReads
        let result = await reader.read(.onThisIPhone)
        if mine == ownReads { results[PresetSource.onThisIPhone.id] = result }
    }

    private func write(_ preset: Preset, to file: String) throws {
        try FileManager.default.createDirectory(at: ownFolder, withIntermediateDirectories: true)
        try PresetJSON.encode(preset).write(to: ownFolder.appendingPathComponent(file), options: .atomic)
    }

    /// The first free file name for `name`, which becomes the name with its number.
    /// `except` is the file being renamed: its own old name is not a clash.
    private func uniqueFile(for name: inout String, except own: String? = nil) -> String {
        let listed = (try? FileManager.default.contentsOfDirectory(atPath: ownFolder.path)) ?? []
        let taken = Set(listed.filter { $0 != own }.map { $0.lowercased() })
        var candidate = name
        var number = 1
        while taken.contains(Self.fileName(for: candidate).lowercased()) {
            number += 1
            // Cut the name, not the number: a numbered name must still be a name the app accepts.
            let suffix = " \(number)"
            candidate = String(name.prefix(PresetValidation.maxNameLength - suffix.count)) + suffix
        }
        name = candidate
        return Self.fileName(for: candidate)
    }

    private static func fileName(for name: String) -> String {
        // No leading dot: a hidden file is never listed.
        let replaced = String(name.map { "/\\:*?\"<>|".contains($0) ? "-" : $0 })
        let cleaned = String(replaced.drop { $0 == "." }).trimmingCharacters(in: .whitespaces)
        return (cleaned.isEmpty ? "Preset" : cleaned) + ".json"
    }
}

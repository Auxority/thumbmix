import Foundation
import Observation

/// A preset as listed: its file On this iPhone or in a picked folder, or its path in a web source's index.
public struct LibraryEntry: Identifiable, Equatable, Sendable {
    /// The id of its `PresetSource`; nil On this iPhone, the only place presets are written.
    public let source: PresetSource.ID?
    public let file: String
    public let preset: Preset
    public var id: String { (source ?? "") + "\n" + file }
    public var isOwn: Bool { source == nil }

    init(source: PresetSource.ID? = nil, file: String, preset: Preset) {
        self.source = source
        self.file = file
        self.preset = preset
    }
}

/// A file On this iPhone that isn't a preset the app takes, named so whoever edited it in Files can find it.
public struct SkippedFile: Equatable, Sendable {
    public let file: String
    public let reason: String
}

public enum LibraryError: LocalizedError, Equatable, Sendable {
    /// Only presets On this iPhone can be changed or removed; "Save a copy" brings one here.
    case readOnly

    public var errorDescription: String? { CoreStrings.text("Only presets on this iPhone can be changed.") }
}

/// The presets On this iPhone (`Documents/Presets`, shown in the Files app, so files can be copied in and out by hand),
/// and those of the sources (`PresetSources`). The app ships none of its own (DECISIONS). Both are read again when
/// the Presets page opens, so an edit made in Files or on the web shows up.
@MainActor @Observable
public final class PresetLibrary {
    public private(set) var own: [LibraryEntry] = []
    public private(set) var skipped: [SkippedFile] = []
    /// The sources, in the order they were added, and the last read of each.
    public internal(set) var sources: [PresetSource] = []
    public internal(set) var results: [PresetSource: SourceResult] = [:]

    @ObservationIgnored private let ownFolder: URL
    @ObservationIgnored let web: PresetSources?
    /// Sources whose read is in flight: a second refresh leaves them to it.
    @ObservationIgnored var reading: Set<PresetSource> = []

    /// Without `sources` the library has no web sources: the tests of own presets need no network.
    public init(ownFolder: URL, sources: PresetSources? = nil) {
        self.ownFolder = ownFolder
        web = sources
        self.sources = sources?.load() ?? []
        refresh()
    }

    /// Own presets, then each source's, in the order of the sources.
    public var entries: [LibraryEntry] { own + sources.flatMap { results[$0]?.presets ?? [] } }

    /// Every own file the app takes, each checked as an imported one is. A file it refuses is listed with its reason.
    public func refresh() {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: ownFolder.path)) ?? []
        var own: [LibraryEntry] = []
        var skipped: [SkippedFile] = []
        for name in names where name.lowercased().hasSuffix(".json") && !name.hasPrefix(".") {
            do {
                own.append(LibraryEntry(file: name, preset: try PresetFiles.preset(at: ownFolder.appendingPathComponent(name))))
            } catch {
                skipped.append(SkippedFile(file: name, reason: error.localizedDescription))
            }
        }
        (self.own, self.skipped) = (own, skipped)
    }

    /// The presets whose match words fit first, then the others, each by name.
    public func ordered(fitting fits: (Preset) -> Bool) -> (fits: [LibraryEntry], others: [LibraryEntry]) {
        let sorted = entries.sorted { $0.preset.name.localizedStandardCompare($1.preset.name) == .orderedAscending }
        return (sorted.filter { fits($0.preset) }, sorted.filter { !fits($0.preset) })
    }

    // MARK: Own presets

    /// Writes a preset On this iPhone as `<name>.json`. A name already taken gets " 2", " 3"... and the preset carries
    /// that name too.
    @discardableResult
    public func save(_ preset: Preset) throws -> LibraryEntry {
        try PresetValidation.validate(preset)
        var named = preset
        let file = uniqueFile(for: &named.name)
        try write(named, to: file)
        refresh()
        return LibraryEntry(file: file, preset: named)
    }

    /// A changed preset replaces the old file; a changed name moves it.
    @discardableResult
    public func replace(_ entry: LibraryEntry, with preset: Preset) throws -> LibraryEntry {
        guard entry.isOwn else { throw LibraryError.readOnly }
        let old = entry.file
        try PresetValidation.validate(preset)
        var renamed = preset
        let file = preset.name == entry.preset.name ? old : uniqueFile(for: &renamed.name, except: old)
        try write(renamed, to: old)
        // A move, not a second file: on a case-insensitive disk "kick" and "Kick" are one file, which a write and a
        // delete would remove.
        if file != old {
            try FileManager.default.moveItem(at: ownFolder.appendingPathComponent(old), to: ownFolder.appendingPathComponent(file))
        }
        refresh()
        return LibraryEntry(file: file, preset: renamed)
    }

    public func remove(_ entry: LibraryEntry) throws {
        guard entry.isOwn else { throw LibraryError.readOnly }
        try FileManager.default.removeItem(at: ownFolder.appendingPathComponent(entry.file))
        refresh()
    }

    /// A file picked in Files or received by AirDrop is copied here, checked as any other. Nothing is asked on import:
    /// asking happens on loading.
    @discardableResult
    public func importPreset(_ data: Data) throws -> LibraryEntry {
        try save(PresetValidation.decode(data))
    }

    /// The preset as a `.json` file under its name, in a folder of its own in the temporary directory.
    public func exportFile(_ preset: Preset) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(Self.fileName(for: preset.name))
        try PresetJSON.encode(preset).write(to: url, options: .atomic)
        return url
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
        // No leading dot, also behind spaces: a hidden file is never listed.
        let replaced = String(name.map { "/\\:*?\"<>|".contains($0) ? "-" : $0 })
        let cleaned = String(replaced.drop { $0 == "." || $0.isWhitespace }).trimmingCharacters(in: .whitespaces)
        return (cleaned.isEmpty ? "Preset" : cleaned) + ".json"
    }
}

import Foundation

/// Where presets come from. Every preset has a source; only On this iPhone is written to.
public struct PresetSource: Identifiable, Codable, Equatable, Sendable {
    public enum Kind: Codable, Equatable, Sendable {
        /// The app's own folder, which Save writes to and the Files app shows.
        case onThisIPhone
        /// A folder picked in Files: every `.json` in it is a preset. Kept across launches by its bookmark.
        case folder(bookmark: Data)
        /// A single preset file picked in Files.
        case file(bookmark: Data)
        /// An HTTPS address of an index (`PresetIndex`) that lists preset files.
        case url(URL)
    }

    public let id: UUID
    public var name: String
    public var kind: Kind

    public init(id: UUID = UUID(), name: String, kind: Kind) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    /// Always the first source and never removable.
    public static let onThisIPhone = PresetSource(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: CoreStrings.text("On this iPhone"),
        kind: .onThisIPhone)

    /// The repo's `presets/` folder: present on first launch, removable, and added back from the Sources page.
    public static let thumbmix = PresetSource(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Thumbmix",
        kind: .url(URL(string: "https://raw.githubusercontent.com/Auxority/thumbmix/main/presets/index.json")!))

    /// Only On this iPhone is written to: the others are read-only, as in SideStore.
    public var isWritable: Bool { kind == .onThisIPhone }
    public var isRemovable: Bool { kind != .onThisIPhone }

    public var kindName: String {
        switch kind {
        case .onThisIPhone: CoreStrings.text("On this iPhone")
        case .folder: CoreStrings.text("Folder")
        case .file: CoreStrings.text("File")
        case .url(let url): url.host ?? CoreStrings.text("Web address")
        }
    }
}

/// The sources the engineer has added, kept in one JSON file. A missing file is a first launch: On this iPhone and the
/// Thumbmix source. After that the file decides, so a removed Thumbmix source stays removed.
struct PresetSourceStore {
    let file: URL
    let includesDefaultSource: Bool

    func load() -> [PresetSource] {
        guard let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode([PresetSource].self, from: data)
        else { return [.onThisIPhone] + (includesDefaultSource ? [.thumbmix] : []) }
        return [.onThisIPhone] + saved.filter { $0.kind != .onThisIPhone }
    }

    func save(_ sources: [PresetSource]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(sources.filter(\.isRemovable)).write(to: file, options: .atomic)
    }
}

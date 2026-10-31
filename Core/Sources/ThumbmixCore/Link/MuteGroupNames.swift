import Foundation

/// The names of one console's mute groups. The desk gives a mute group no name (doc p.21), so they live on this iPhone;
/// no name is "unnamed", which the app shows as today (spec 2026-10-31-mute-group-names).
public struct MuteGroupNames: Equatable, Sendable {
    private var byGroup: [Int: String] = [:]

    public init() {}

    /// Stored as plain strings under "1" … "6", so a plist holds it; anything else in it is dropped.
    public init(stored: Any?) {
        for (key, value) in stored as? [String: Any] ?? [:] {
            if let group = Int(key), let text = value as? String { set(text, for: group) }
        }
    }

    public var stored: [String: String] {
        Dictionary(uniqueKeysWithValues: byGroup.map { (String($0.key), $0.value) })
    }

    public func name(of group: Int) -> String? { byGroup[group] }

    /// Typed under a strip name's rules; an empty name unnames the group.
    public mutating func set(_ text: String, for group: Int) {
        guard (1...Catalog.muteGroupCount).contains(group) else { return }
        let name = StripName.sanitized(text)
        byGroup[group] = name.isEmpty ? nil : name
    }
}

/// Every remembered console's group names, by `NetworkConsole.id` as `KnownConsoles` keys a desk.
public struct MuteGroupNameBook: Equatable, Sendable {
    private var byConsole: [String: MuteGroupNames] = [:]

    public init() {}

    public init(stored: Any?) {
        for (id, names) in stored as? [String: Any] ?? [:] { set(MuteGroupNames(stored: names), of: id) }
    }

    public var stored: [String: [String: String]] { byConsole.mapValues(\.stored) }

    public func names(of consoleID: String) -> MuteGroupNames { byConsole[consoleID] ?? MuteGroupNames() }

    public mutating func set(_ names: MuteGroupNames, of consoleID: String) {
        byConsole[consoleID] = names == MuteGroupNames() ? nil : names
    }

    public mutating func forget(_ consoleID: String) {
        byConsole[consoleID] = nil
    }
}

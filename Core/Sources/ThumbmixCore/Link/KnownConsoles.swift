import Foundation

/// Every console the app connected to, the last one first.
public struct KnownConsoles: Equatable, Sendable {
    public private(set) var all: [NetworkConsole]

    public init(_ all: [NetworkConsole] = []) {
        self.all = all
    }

    /// Stored as plain dictionaries, so a UI test can seed or clear it with a launch argument.
    public init(stored: Any?) {
        let entries = stored as? [Any] ?? []
        all = entries.compactMap { entry in
            guard let fields = entry as? [String: String], let host = fields["host"], let name = fields["name"],
                let model = fields["model"]
            else { return nil }
            return NetworkConsole(host: host, name: name, model: model)
        }
    }

    public var stored: [[String: String]] {
        all.map { ["host": $0.host, "name": $0.name, "model": $0.model] }
    }

    public var lastUsed: NetworkConsole? { all.first }
    public var others: [NetworkConsole] { Array(all.dropFirst()) }

    public mutating func remember(_ console: NetworkConsole) {
        forget(console)
        all.insert(console, at: 0)
    }

    public mutating func forget(_ console: NetworkConsole) {
        all.removeAll { $0.id == console.id }
    }
}

public enum Presence: Equatable, Sendable {
    /// No scan has answered yet; the row shows no state rather than a guess.
    case unknown
    case online
    case notFound
    case notAnM32
}

/// What one visit to the Connect screen has seen. A console found for the first time goes after the rows
/// already shown, so a late answer never moves the row under a thumb.
public struct ConsoleSightings: Equatable, Sendable {
    private var newcomers: [NetworkConsole] = []
    /// The latest scan's answers by `NetworkConsole.id`; nil until a scan ends.
    private var answered: [String: NetworkConsole]?

    public init() {}

    public mutating func scanned(_ consoles: [NetworkConsole], known: KnownConsoles) {
        answered = Dictionary(consoles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let shown = Set((known.all + newcomers).map(\.id))
        newcomers += consoles.filter { !shown.contains($0.id) }
    }

    public func rows(known: KnownConsoles) -> [NetworkConsole] {
        let remembered = Set(known.all.map(\.id))
        return known.others + newcomers.filter { !remembered.contains($0.id) }
    }

    public func presence(of console: NetworkConsole) -> Presence {
        guard let answered else { return .unknown }
        guard let answer = answered[console.id] else { return .notFound }
        return answer.model.hasPrefix("M32") ? .online : .notAnM32
    }

    /// What the latest scan saw of a console, for the log: a renamed desk or a new address reads differently from
    /// silence, though all three are Not found.
    public func sighting(of console: NetworkConsole) -> Sighting {
        guard let answered else { return .notScanned }
        if let answer = answered[console.id] { return .answered(model: answer.model) }
        if let other = answered.values.first(where: { $0.host == console.host }) {
            return .addressAnsweredAs(name: other.name)
        }
        if let moved = answered.values.first(where: { $0.name == console.name }) {
            return .nameAnsweredFrom(host: moved.host)
        }
        return .noReply
    }
}

public enum Sighting: Equatable, Sendable {
    case notScanned
    case answered(model: String)
    case addressAnsweredAs(name: String)
    case nameAnsweredFrom(host: String)
    case noReply
}

extension Discovery {
    /// The phone's /24, plus every remembered console: one on a routed VLAN can still answer directly.
    public static func scanHosts(around ip: String?, known: [String]) -> [String] {
        let sweep = ip.map { sweepHosts(around: $0) } ?? []
        let swept = Set(sweep)
        var extra: [String] = []
        for host in known where !swept.contains(host) && !extra.contains(host) { extra.append(host) }
        return sweep + extra
    }

    /// Where typing an address starts: this phone's network, so at a venue only the last number is typed.
    public static func networkPrefix(of ip: String?) -> String {
        guard let ip, isUsableIPv4(ip) else { return "" }
        return ip.split(separator: ".").prefix(3).joined(separator: ".") + "."
    }

    /// The decimal keypad types the region's separator, a comma in the Netherlands; an address never holds one.
    public static func typedAddress(_ text: String) -> String? {
        let host = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return isUsableIPv4(host) ? host : nil
    }
}

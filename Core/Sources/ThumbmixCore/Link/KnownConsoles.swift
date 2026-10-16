import Foundation

/// A console as the Connect screen lists it: remembered, or found by a scan.
public struct KnownConsole: Equatable, Sendable, Identifiable {
    public let host: String
    public let name: String
    public let model: String

    public init(host: String, name: String, model: String) {
        self.host = host
        self.name = name
        self.model = model
    }

    public init(_ found: DiscoveredConsole) {
        self.init(host: found.host, name: found.name, model: found.model)
    }

    /// The address and the desk's name together: two venues' desks can share an address like 192.168.1.50.
    public var id: String { "\(name)@\(host)" }
}

/// Every console the app connected to, the last one first.
public struct KnownConsoles: Equatable, Sendable {
    public private(set) var all: [KnownConsole]

    public init(_ all: [KnownConsole] = []) {
        self.all = all
    }

    /// Stored as plain dictionaries, so a UI test can seed or clear it with a launch argument.
    public init(stored: Any?) {
        let entries = stored as? [Any] ?? []
        all = entries.compactMap { entry in
            guard let fields = entry as? [String: String], let host = fields["host"], let name = fields["name"],
                let model = fields["model"]
            else { return nil }
            return KnownConsole(host: host, name: name, model: model)
        }
    }

    public var stored: [[String: String]] {
        all.map { ["host": $0.host, "name": $0.name, "model": $0.model] }
    }

    public var lastUsed: KnownConsole? { all.first }
    public var others: [KnownConsole] { Array(all.dropFirst()) }

    public mutating func remember(_ console: KnownConsole) {
        forget(console)
        all.insert(console, at: 0)
    }

    public mutating func forget(_ console: KnownConsole) {
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
    private var newcomers: [KnownConsole] = []
    /// The latest scan's answers by `KnownConsole.id`; nil until a scan ends.
    private var answered: [String: KnownConsole]?

    public init() {}

    public mutating func scanned(_ found: [DiscoveredConsole], known: KnownConsoles) {
        let consoles = found.map(KnownConsole.init)
        answered = Dictionary(consoles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let shown = Set((known.all + newcomers).map(\.id))
        newcomers += consoles.filter { !shown.contains($0.id) }
    }

    public func rows(known: KnownConsoles) -> [KnownConsole] {
        let remembered = Set(known.all.map(\.id))
        return known.others + newcomers.filter { !remembered.contains($0.id) }
    }

    public func presence(of console: KnownConsole) -> Presence {
        guard let answered else { return .unknown }
        guard let answer = answered[console.id] else { return .notFound }
        return answer.model.hasPrefix("M32") ? .online : .notAnM32
    }
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

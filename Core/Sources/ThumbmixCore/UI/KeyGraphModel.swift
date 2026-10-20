import Foundation

/// Whose key: the gate's or the comp's. Each has its own source and filter (doc p.25-37).
public enum KeyOwner: Sendable {
    case gate, comp
}

/// One of the desk's key filters, in `Catalog.keyFilterTypes` order: LC6, LC12, HC6, HC12, then band-passes with
/// Q 1, 2, 3, 5 and 10. The doc names them only: drawn as first-order and Butterworth cuts (-3 dB at the frequency)
/// and second-order band-passes peaking at 0 dB, an assumption until checked on the desk (TODO).
public struct KeyFilterState: Equatable, Sendable {
    public let typeIndex: Int
    public let frequency: Double

    public init(typeIndex: Int, frequency: Double) {
        self.typeIndex = typeIndex
        self.frequency = frequency
    }

    private static let bandPassQs: [Double] = [1, 2, 3, 5, 10]

    public func decibels(at hertz: Double) -> Double {
        let ratio = hertz / frequency
        switch typeIndex {
        case 0: return -10 * log10(1 + pow(ratio, -2))
        case 1: return -10 * log10(1 + pow(ratio, -4))
        case 2: return -10 * log10(1 + pow(ratio, 2))
        case 3: return -10 * log10(1 + pow(ratio, 4))
        default:
            let q = Self.bandPassQs[min(max(typeIndex - 4, 0), Self.bandPassQs.count - 1)]
            return -10 * log10(1 + q * q * pow(ratio - 1 / ratio, 2))
        }
    }
}

extension ConsoleMirror {
    /// nil until the desk sent the type and frequency: the graph never draws a guessed shape.
    public func keyFilter(_ key: KeySpecs) -> KeyFilterState? {
        guard let type = value(key.filterType), let frequency = value(key.filterFrequency) else { return nil }
        return KeyFilterState(typeIndex: Int(type), frequency: frequency)
    }

    public func isKeyFilterOn(_ key: KeySpecs) -> Bool? {
        value(key.filterOn).map { $0 >= 1 }
    }

    /// The strip the key listens to, and whether the RTA shows it after its EQ: what the gate or comp hears. A gate
    /// sits before the EQ (unverified); a comp keyed on itself hears its own position; another strip is taken before
    /// its EQ (unverified, TODO). nil while anything it depends on is unread: the app never borrows the RTA on a guess.
    public func keyRTA(_ strip: StripID, owner: KeyOwner) -> (strip: StripID, afterEQ: Bool)? {
        let key = owner == .gate ? Catalog.gateKey(strip) : Catalog.dynamicsKey(strip)
        if let address = key.sourceAddress {
            guard case .int(let source)? = cell(address).argument else { return nil }
            if source > 0 { return keySource(Int(source)).map { ($0, false) } }
        }
        guard owner == .comp else { return (strip, false) }
        guard let position = Catalog.dynamicsPosition(strip), let after = value(position) else { return nil }
        return (strip, after >= 1)
    }

    /// `keysrc` 1-64 (0 is the strip itself).
    private func keySource(_ index: Int) -> StripID? {
        Catalog.keySources.indices.contains(index - 1) ? Catalog.keySources[index - 1] : nil
    }
}

extension RTA {
    /// Each band's level after `response` (its dB at that band's frequency): what reaches the detector. Never above 0.
    public static func filtered(_ decibels: [Float], by response: (Double) -> Double) -> [Float] {
        decibels.enumerated().map { band, level in min(level + Float(response(bandFrequency(band))), 0) }
    }
}

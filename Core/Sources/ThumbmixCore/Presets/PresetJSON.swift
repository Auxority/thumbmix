import Foundation

/// The file format (`"format": "thumbmix-preset"`, `"version": 1`). Reading goes through `PresetValidation.decode`,
/// which checks the file before and after this decoding.
public enum PresetJSON {
    public static let format = "thumbmix-preset"
    public static let version = 1

    public static func encode(_ preset: Preset) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(preset)
    }
}

extension StripKind: Codable {}

extension Preset: Codable {
    private enum Key: String, CodingKey {
        case format, version, name, matchWords, stripKind, input, eq, gate, comp, mix, sends
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            matchWords: try container.decode([String].self, forKey: .matchWords),
            stripKind: try container.decode(StripKind.self, forKey: .stripKind),
            input: try container.decodeIfPresent(InputPart.self, forKey: .input),
            eq: try container.decodeIfPresent(EQPart.self, forKey: .eq),
            gate: try container.decodeIfPresent(GatePart.self, forKey: .gate),
            comp: try container.decodeIfPresent(CompPart.self, forKey: .comp),
            mix: try container.decodeIfPresent(MixPart.self, forKey: .mix),
            sends: try container.decodeIfPresent([String: SendPart].self, forKey: .sends))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(PresetJSON.format, forKey: .format)
        try container.encode(PresetJSON.version, forKey: .version)
        try container.encode(name, forKey: .name)
        try container.encode(matchWords, forKey: .matchWords)
        try container.encode(stripKind, forKey: .stripKind)
        try container.encodeIfPresent(input, forKey: .input)
        try container.encodeIfPresent(eq, forKey: .eq)
        try container.encodeIfPresent(gate, forKey: .gate)
        try container.encodeIfPresent(comp, forKey: .comp)
        try container.encodeIfPresent(mix, forKey: .mix)
        try container.encodeIfPresent(sends, forKey: .sends)
    }
}

extension MixPart: Codable {
    private enum Key: String, CodingKey { case faderDb, pan }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.init(
            faderDb: try container.decodeLevel(forKey: .faderDb), pan: try container.decodeIfPresent(Double.self, forKey: .pan))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encodeLevel(faderDb, forKey: .faderDb)
        try container.encodeIfPresent(pan, forKey: .pan)
    }
}

extension SendPart: Codable {
    private enum Key: String, CodingKey { case levelDb, on, tap }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.init(
            levelDb: try container.decodeLevel(forKey: .levelDb), on: try container.decode(Bool.self, forKey: .on),
            tap: try container.decodeIfPresent(String.self, forKey: .tap))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encodeLevel(levelDb, forKey: .levelDb)
        try container.encode(on, forKey: .on)
        try container.encodeIfPresent(tap, forKey: .tap)
    }
}

/// A level can be -∞, which JSON has no number for: it is the text "-inf", and only levels accept it.
extension KeyedDecodingContainer {
    fileprivate func decodeLevel(forKey key: Key) throws -> Double {
        if let number = try? decode(Double.self, forKey: key) { return number }
        if try decode(String.self, forKey: key) == "-inf" { return -.infinity }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "not a level")
    }
}

extension KeyedEncodingContainer {
    fileprivate mutating func encodeLevel(_ level: Double, forKey key: Key) throws {
        if level == -.infinity { try encode("-inf", forKey: key) } else { try encode(level, forKey: key) }
    }
}

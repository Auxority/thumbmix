import Foundation

/// The file format (`"format": "thumbmix-preset"`, `"version": 1`): the name, match words and strip kind, then each
/// part the preset holds as an object of values by path. Reading goes through `PresetValidation.decode`.
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
    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }

        static let format = Key(stringValue: "format")
        static let version = Key(stringValue: "version")
        static let name = Key(stringValue: "name")
        static let matchWords = Key(stringValue: "matchWords")
        static let stripKind = Key(stringValue: "stripKind")
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        name = try container.decode(String.self, forKey: .name)
        matchWords = try container.decode([String].self, forKey: .matchWords)
        stripKind = try container.decode(StripKind.self, forKey: .stripKind)
        for part in PresetPart.allCases {
            values[part] = try container.decodeIfPresent([String: PresetValue].self, forKey: Key(stringValue: part.rawValue))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(PresetJSON.format, forKey: .format)
        try container.encode(PresetJSON.version, forKey: .version)
        try container.encode(name, forKey: .name)
        try container.encode(matchWords, forKey: .matchWords)
        try container.encode(stripKind, forKey: .stripKind)
        for (part, values) in values { try container.encode(values, forKey: Key(stringValue: part.rawValue)) }
    }
}

/// `true`/`false` is a switch, a number a number, text a choice. A level can be -∞, which JSON has no number for: it
/// is the text "-inf".
extension PresetValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let flag = try? container.decode(Bool.self) {
            self = .flag(flag)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else {
            let text = try container.decode(String.self)
            self = text == "-inf" ? .number(-.infinity) : .option(text)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .flag(let flag): try container.encode(flag)
        case .number(let number) where number == -.infinity: try container.encode("-inf")
        case .number(let number): try container.encode(number)
        case .option(let name): try container.encode(name)
        }
    }
}

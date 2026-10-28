import Foundation

/// Why a preset file was refused. Every case names the field, so whoever edited the file can find it.
public enum PresetError: Error, Equatable, Sendable {
    case notAPreset
    case unknownVersion(Int)
    case tooLarge
    case missing(field: String)
    case wrongType(field: String)
    case outOfRange(field: String)
    case unknownOption(field: String, value: String)
    case badText(field: String)
    /// The strip type the preset was saved from has no such control.
    case notForStrip(field: String)

    public var message: String {
        switch self {
        case .notAPreset: CoreStrings.text("This is not a Thumbmix preset file.")
        case .unknownVersion(let version): CoreStrings.text("This preset is version \(version); this app reads version 1.")
        case .tooLarge: CoreStrings.text("This file is too large for a preset.")
        case .missing(let field): CoreStrings.text("\(field) is missing.")
        case .wrongType(let field): CoreStrings.text("\(field) holds the wrong kind of value.")
        case .outOfRange(let field): CoreStrings.text("\(field) is outside what the desk takes.")
        case .unknownOption(let field, let value): CoreStrings.text("\(field): the desk has no option \(value).")
        case .badText(let field): CoreStrings.text("\(field) is empty, too long or holds control characters.")
        case .notForStrip(let field): CoreStrings.text("\(field) has no control on this kind of strip.")
        }
    }
}

/// The one check every preset passes before the app keeps or shows it, whichever source it came from.
public enum PresetValidation {
    public static let maxBytes = 32 * 1024
    static let maxNameLength = 40
    static let maxMatchWords = 10
    static let maxMatchWordLength = 20

    /// Reads a file: size, format, version, then every value against what the desk takes. Nothing is clamped.
    public static func decode(_ data: Data) throws -> Preset {
        guard data.count <= maxBytes else { throw PresetError.tooLarge }
        let header = try? JSONDecoder().decode(Header.self, from: data)
        guard header?.format == PresetJSON.format else { throw PresetError.notAPreset }
        guard header?.version == PresetJSON.version else { throw PresetError.unknownVersion(header?.version ?? 0) }
        let preset: Preset
        do {
            preset = try JSONDecoder().decode(Preset.self, from: data)
        } catch let error as DecodingError {
            throw PresetError(error)
        }
        try validate(preset)
        return preset
    }

    public static func validate(_ preset: Preset) throws {
        try validateText(preset)
        let strip = StripID(preset.stripKind, 1)
        guard preset.stripKind != .dca else { throw PresetError.notForStrip(field: "stripKind") }
        try validateShape(preset, strip)
        for part in PresetPart.allCases {
            // Any preamp: ranges are the same for all 128.
            for field in preset.fields(of: part, on: strip, headamp: 0) { try validate(field) }
        }
    }

    private static func validateText(_ preset: Preset) throws {
        guard isPlain(preset.name, maxLength: maxNameLength) else { throw PresetError.badText(field: "name") }
        guard preset.matchWords.count <= maxMatchWords else { throw PresetError.badText(field: "matchWords") }
        for (index, word) in preset.matchWords.enumerated() where !isPlain(word, maxLength: maxMatchWordLength) {
            throw PresetError.badText(field: "matchWords[\(index + 1)]")
        }
    }

    private static func isPlain(_ text: String, maxLength: Int) -> Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && text.count <= maxLength
            && !text.unicodeScalars.contains { $0.properties.generalCategory == .control }
    }

    /// What the strip type decides before any value: which parts and how many bands and sends exist.
    private static func validateShape(_ preset: Preset, _ strip: StripID) throws {
        if preset.input != nil, !ChannelTab.tabs(for: strip.kind).contains(.input) {
            throw PresetError.notForStrip(field: "input")
        }
        if let eq = preset.eq, eq.bands.count != strip.eqBandCount { throw PresetError.outOfRange(field: "eq.bands") }
        guard let sends = preset.sends else { return }
        guard let target = strip.kind.sendTarget else { throw PresetError.notForStrip(field: "sends") }
        for key in sends.keys.sorted() where !(Int(key).map { (1...target.count).contains($0) } ?? false) {
            throw PresetError.outOfRange(field: "sends.\(key)")
        }
    }

    private static func validate(_ field: PresetField) throws {
        guard let spec = field.spec else { throw PresetError.notForStrip(field: field.path) }
        switch (field.value, spec.scale) {
        case (.flag, .toggle): return
        case (.option(let name), .choice(let options)):
            if !options.contains(name) { throw PresetError.unknownOption(field: field.path, value: name) }
        case (.number, .toggle), (.number, .choice):
            throw PresetError.wrongType(field: field.path)
        case (.number(let number), let scale):
            guard isInRange(number, scale) else { throw PresetError.outOfRange(field: field.path) }
        default: throw PresetError.wrongType(field: field.path)
        }
    }

    /// Between the scale's ends, the edges included. A level may be -∞.
    private static func isInRange(_ number: Double, _ scale: ParamScale) -> Bool {
        guard !number.isNaN else { return false }
        let ends = [scale.value(fromNormalized: 0), scale.value(fromNormalized: 1)]
        let (low, high) = (ends.min() ?? 0, ends.max() ?? 0)
        let slack = 1e-9 * max(1, abs(high), abs(low.isFinite ? low : 0))
        return number >= low - slack && number <= high + slack
    }

    private struct Header: Decodable {
        let format: String?
        let version: Int?
    }
}

extension PresetError {
    fileprivate init(_ error: DecodingError) {
        switch error {
        case .keyNotFound(let key, let context): self = .missing(field: Self.path(context.codingPath + [key]))
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            self = context.codingPath.isEmpty ? .notAPreset : .wrongType(field: Self.path(context.codingPath))
        @unknown default: self = .notAPreset
        }
    }

    /// "eq.bands[2].hz": an array position counts from 1, as the app lists it.
    private static func path(_ keys: [CodingKey]) -> String {
        keys.reduce("") { path, key in
            if let index = key.intValue { return path + "[\(index + 1)]" }
            return path.isEmpty ? key.stringValue : path + "." + key.stringValue
        }
    }
}

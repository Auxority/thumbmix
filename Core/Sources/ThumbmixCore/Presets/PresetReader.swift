import Foundation

/// One part of a preset as the preset page reads it: each value by its path, in compact text (`ValueText.parts`).
/// Read from the preset alone, never from the desk.
struct PresetReader {
    let strip: StripID
    let fields: [PresetField]
    let locale: Locale
    private let byPath: [String: PresetField]

    init(_ preset: Preset, _ part: PresetPart, _ locale: Locale) {
        strip = StripID(preset.stripKind, 1)
        fields = preset.fields(of: part, on: strip, headamp: 0)
        byPath = Dictionary(fields.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        self.locale = locale
    }

    func field(_ path: String) -> PresetField? { byPath[path] }

    func flag(_ path: String) -> Bool? {
        guard case .flag(let on)? = byPath[path]?.value else { return nil }
        return on
    }

    func option(_ path: String) -> String? {
        guard case .option(let name)? = byPath[path]?.value else { return nil }
        return name
    }

    func number(_ path: String) -> Double? {
        guard case .number(let number)? = byPath[path]?.value else { return nil }
        return number
    }

    func parts(_ path: String) -> ValueParts? { byPath[path].map(parts) }

    func parts(_ field: PresetField) -> ValueParts {
        if field.role == .polarity, case .flag(let flipped) = field.value {
            return ValueParts(number: flipped ? CoreStrings.text("Flipped") : CoreStrings.text("Normal"))
        }
        guard let spec = field.spec, let real = field.real else { return ValueParts(number: Self.raw(field.value)) }
        return ValueText.parts(spec.scale.normalized(forValue: real), spec, locale: locale)
    }

    /// The label a page shows: the tab's own, made shorter where a group's title already says the rest.
    func label(_ path: String) -> String {
        if let short = Self.shortLabel(path) { return short }
        return byPath[path]?.spec?.label ?? path
    }

    private static func shortLabel(_ path: String) -> String? {
        if path.hasSuffix("filter/f") { return CoreStrings.text("Freq") }
        switch path {
        case "dyn/mgain": return CoreStrings.text("Makeup")
        case "dyn/mix": return CoreStrings.text("Mix")
        case "dyn/auto": return CoreStrings.text("Auto")
        case "dyn/pos": return CoreStrings.text("Position")
        default: return nil
        }
    }

    /// A value whose control this strip lacks, or that doesn't suit it: shown as written, never hidden.
    private static func raw(_ value: PresetValue) -> String {
        switch value {
        case .number(let number): String(number)
        case .flag(let on): on ? CoreStrings.text("On") : CoreStrings.text("Off")
        case .option(let name): name
        }
    }
}

/// One send of a preset: the bus it feeds and its values, from "mix/03/level", "mix/03/on" and "mix/03/type".
struct PresetSend {
    let bus: StripID
    let paths: [String]
    let isOn: Bool
    /// On and above −∞: a send that's on at −∞ (every send's default on the desk) sends nothing.
    let isSending: Bool
    let level: ValueParts
    /// Only where it isn't after the fader, the desk's usual tap for a send.
    let tap: String?

    static func all(in reader: PresetReader) -> [PresetSend] {
        guard let kind = reader.strip.kind.sendTarget else { return [] }
        let numbers = Set(reader.fields.compactMap { number(of: $0.path) }).sorted()
        return numbers.map { send(StripID(kind, $0), in: reader) }
    }

    /// "mix/03/level" → 3; nil for anything else.
    static func number(of path: String) -> Int? {
        let steps = path.split(separator: "/")
        guard steps.count == 3, steps[0] == "mix" else { return nil }
        return Int(steps[1])
    }

    private static func send(_ bus: StripID, in reader: PresetReader) -> PresetSend {
        let prefix = String(format: "mix/%02d/", bus.number)
        let paths = reader.fields.map(\.path).filter { $0.hasPrefix(prefix) }
        let tap = reader.option(prefix + "type").flatMap { name in SendTap.allCases.first { $0.deskAbbreviation == name } }
        let isOn = reader.flag(prefix + "on") ?? false
        return PresetSend(
            bus: bus, paths: paths, isOn: isOn,
            isSending: isOn && reader.number(prefix + "level").map(\.isFinite) == true,
            level: reader.parts(prefix + "level") ?? ValueParts(number: "—"),
            tap: tap == .postFader ? nil : tap?.deskTerm)
    }

    var text: String { tap.map { level.text + " · " + $0 } ?? level.text }
}

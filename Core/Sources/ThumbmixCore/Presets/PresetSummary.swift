import Foundation

public struct PresetRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public var value: String
}

/// A preset's page: what each part holds, as label and value (one text size, as the Settings app lists them), and
/// the EQ as a curve. Read from the preset alone, never from the desk.
public enum PresetSummary {
    /// A row per control, in the part's order, named as its tab names it. An EQ band, a send and a key filter are one
    /// row each: "Band 2 · Parametric EQ · 400 Hz · +3.0 dB · Q 2.0".
    public static func rows(_ preset: Preset, _ part: PresetPart, locale: Locale = .current) -> [PresetRow] {
        let strip = StripID(preset.stripKind, 1)
        var rows: [PresetRow] = []
        for field in preset.fields(of: part, on: strip, headamp: 0) {
            guard let group = group(field.path, strip) else {
                rows.append(PresetRow(id: field.path, label: field.spec?.label ?? field.path, value: text(field, locale)))
                continue
            }
            let text = text(field, locale, inGroup: true)
            if rows.last?.id == group.id {
                rows[rows.count - 1].value += " · " + text
            } else {
                rows.append(PresetRow(id: group.id, label: group.label, value: text))
            }
        }
        return rows
    }

    /// The EQ as it would sound switched on, whatever its switch holds: the page shows what the preset *is*.
    /// nil when the preset holds no EQ, or a band the app can't draw.
    public static func eqCurve(_ preset: Preset) -> (bands: [EQBandState], lowCut: LowCutState?)? {
        let strip = StripID(preset.stripKind, 1)
        guard preset.holds(.eq), strip.eqBandCount > 0 else { return nil }
        let bands = (1...strip.eqBandCount).compactMap { band(preset, Catalog.eqBand(strip, $0), strip) }
        guard bands.count == strip.eqBandCount else { return nil }
        let lowCut = Catalog.lowCut(strip).flatMap { specs -> LowCutState? in
            guard value(preset, specs.on, strip) == .flag(true), case .number(let hertz)? = value(preset, specs.frequency, strip)
            else { return nil }
            return LowCutState(frequency: hertz)
        }
        return (bands, lowCut)
    }

    private static func band(_ preset: Preset, _ specs: EQBandSpecs, _ strip: StripID) -> EQBandState? {
        guard case .option(let name)? = value(preset, specs.type, strip),
            let type = EQFilterType.allCases.first(where: { $0.deskName == name }),
            case .number(let hertz)? = value(preset, specs.frequency, strip),
            case .number(let gain)? = value(preset, specs.gain, strip), case .number(let q)? = value(preset, specs.q, strip)
        else { return nil }
        return EQBandState(typeIndex: type.rawValue, frequency: hertz, gain: gain, q: q)
    }

    private static func value(_ preset: Preset, _ spec: ParamSpec, _ strip: StripID) -> PresetValue? {
        preset.values[.eq]?[PresetPart.path(of: spec, on: strip)]
    }

    /// The row a control shares with its neighbours: the low cut, an EQ band ("eq/2/f"), a send ("mix/03/level"), a
    /// key filter.
    private static func group(_ path: String, _ strip: StripID) -> (id: String, label: String)? {
        if path.hasPrefix("preamp/hp") { return ("preamp/hp", CoreStrings.text("Low cut")) }
        let steps = path.split(separator: "/")
        guard steps.count == 3 else { return nil }
        let id = steps.dropLast().joined(separator: "/")
        if steps[1] == "filter" { return (id, CoreStrings.text("Key filter")) }
        guard let number = Int(steps[1]) else { return nil }
        if steps[0] == "eq" { return (id, CoreStrings.text("Band \(number)")) }
        guard steps[0] == "mix", let kind = strip.kind.sendTarget else { return nil }
        return (id, StripID(kind, number).defaultName)
    }

    /// In a shared row a bare number says what it is ("Q 2.0"); a unit says it already.
    private static func text(_ field: PresetField, _ locale: Locale, inGroup: Bool = false) -> String {
        let text = display(field, locale)
        guard inGroup, let spec = field.spec, spec.unit == .plain, case .number = field.value else { return text }
        return spec.label + " " + text
    }

    private static func display(_ field: PresetField, _ locale: Locale) -> String {
        switch field.value {
        case .flag(let on):
            if field.role == .polarity { return on ? CoreStrings.text("Flipped") : CoreStrings.text("Normal") }
            return on ? CoreStrings.text("On") : CoreStrings.text("Off")
        case .option(let name):
            guard let spec = field.spec, case .choice(let options) = spec.scale, let index = options.firstIndex(of: name)
            else { return name }
            if spec.unit == .ratio { return name + ":1" }
            return spec.optionNames?[index] ?? name
        case .number(let number):
            guard let spec = field.spec else { return String(number) }
            return ValueText.format(spec.scale.normalized(forValue: number), spec, locale: locale)
        }
    }
}

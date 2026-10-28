import Foundation

public struct PresetRow: Equatable, Identifiable, Sendable {
    public let label: String
    public let value: String
    public var id: String { label }
}

/// A preset's page: what each part holds, as label and value (one text size, as the Settings app lists them), and
/// the EQ as a curve. Read from the preset alone, never from the desk.
public enum PresetSummary {
    public static func rows(_ preset: Preset, _ part: PresetPart, locale: Locale = .current) -> [PresetRow] {
        let strip = StripID(preset.stripKind, 1)
        let fields = preset.fields(of: part, on: strip, headamp: 0)
        switch part {
        case .eq: return eqRows(preset, locale)
        case .sends: return sendRows(preset, strip, locale)
        default:
            let plain = fields.filter { !$0.path.contains("keyFilter") }.map { row($0, locale) }
            return plain + keyFilterRow(preset, part, locale)
        }
    }

    /// The EQ as it would sound switched on, whatever its switch holds: the page shows what the preset *is*.
    /// nil when the preset holds no EQ, or a band type the app doesn't know.
    public static func eqCurve(_ preset: Preset) -> (bands: [EQBandState], lowCut: LowCutState?)? {
        guard let eq = preset.eq else { return nil }
        let bands = eq.bands.compactMap { band in
            filterType(band.type).map {
                EQBandState(typeIndex: $0.rawValue, frequency: band.hz, gain: band.db, q: band.q)
            }
        }
        guard bands.count == eq.bands.count else { return nil }
        return (bands, eq.lowCut.flatMap { $0.on ? LowCutState(frequency: $0.hz) : nil })
    }

    private static func row(_ field: PresetField, _ locale: Locale) -> PresetRow {
        PresetRow(label: field.spec?.label ?? field.path, value: display(field, locale))
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

    private static func keyFilterRow(_ preset: Preset, _ part: PresetPart, _ locale: Locale) -> [PresetRow] {
        let filter = part == .gate ? preset.gate?.keyFilter : preset.comp?.keyFilter
        guard let filter else { return [] }
        let hertz = ValueText.format(
            Catalog.gateKey(StripID(.input, 1)).filterFrequency.scale.normalized(forValue: filter.hz),
            Catalog.gateKey(StripID(.input, 1)).filterFrequency, locale: locale)
        let value = filter.on ? "\(filter.type) · \(hertz)" : CoreStrings.text("Off")
        return [PresetRow(label: CoreStrings.text("Key filter"), value: value)]
    }

    /// The low cut, then each band that does something: a flat shelf or bell is left out.
    private static func eqRows(_ preset: Preset, _ locale: Locale) -> [PresetRow] {
        guard let eq = preset.eq else { return [] }
        var rows = [PresetRow(label: CoreStrings.text("EQ"), value: eq.on ? CoreStrings.text("On") : CoreStrings.text("Off"))]
        if let lowCut = eq.lowCut, let spec = Catalog.lowCut(StripID(.input, 1))?.frequency {
            let hertz = ValueText.format(spec.scale.normalized(forValue: lowCut.hz), spec, locale: locale)
            rows.append(PresetRow(label: CoreStrings.text("Low cut"), value: lowCut.on ? hertz : CoreStrings.text("Off")))
        }
        let specs = Catalog.eqBand(StripID(preset.stripKind, 1), 1)
        for (index, band) in eq.bands.enumerated() where band.db != 0 || isCut(band.type) {
            let hertz = ValueText.format(specs.frequency.scale.normalized(forValue: band.hz), specs.frequency, locale: locale)
            let gain = isCut(band.type) ? "" : " · " + ValueText.decibels(band.db, locale: locale)
            let type = filterType(band.type)?.name ?? band.type
            rows.append(PresetRow(label: CoreStrings.text("Band \(index + 1)"), value: "\(type) · \(hertz)\(gain)"))
        }
        return rows
    }

    private static func filterType(_ deskName: String) -> EQFilterType? {
        EQFilterType.allCases.first { $0.deskName == deskName }
    }

    private static func isCut(_ type: String) -> Bool {
        filterType(type).map { !$0.shapesLevel } ?? false
    }

    private static func sendRows(_ preset: Preset, _ strip: StripID, _ locale: Locale) -> [PresetRow] {
        guard let sends = preset.sends, let kind = strip.kind.sendTarget else { return [] }
        return sends.keys.compactMap(Int.init).sorted().compactMap { number in
            guard let send = sends[String(number)] else { return nil }
            let spec = Catalog.sendLevel(from: strip, to: StripID(kind, number))
            var parts = [ValueText.format(spec.scale.normalized(forValue: send.levelDb), spec, locale: locale)]
            parts.append(send.on ? CoreStrings.text("On") : CoreStrings.text("Off"))
            if let tap = send.tap { parts.append(SendTap.allCases.first { $0.deskAbbreviation == tap }?.name ?? tap) }
            return PresetRow(label: StripID(kind, number).defaultName, value: parts.joined(separator: " · "))
        }
    }
}

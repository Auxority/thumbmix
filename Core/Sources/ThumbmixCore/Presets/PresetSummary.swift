import Foundation

/// What the preset page shows of a preset: its overview, every value in groups, and its parts' curves. Read from the
/// preset alone, never from the desk.
public enum PresetSummary {
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
}

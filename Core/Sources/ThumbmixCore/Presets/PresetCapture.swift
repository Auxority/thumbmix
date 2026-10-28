import Foundation

extension ChannelTab {
    /// The tabs whose values a preset saves or loads: all but the lists of who feeds the strip.
    public static func presetTabs(for kind: StripKind) -> [ChannelTab] {
        tabs(for: kind).filter { $0 != .fedBy && $0 != .members }
    }
}

extension ConsoleMirror {
    /// The strip's ticked parts as a preset, nil until every value they hold was read: a preset is never saved from a
    /// guess (the safety rule). A part the strip lacks is left out. Saving reads the side that is open: a linked pair's
    /// partner is not asked.
    public func capture(_ strip: StripID, parts: Set<PresetPart>, name: String, matchWords: [String]) -> Preset? {
        var preset = Preset(name: name, matchWords: matchWords, stripKind: strip.kind)
        for part in PresetPart.allCases where parts.contains(part) && part.exists(on: strip) {
            guard let values = values(of: part, on: strip) else { return nil }
            preset.values[part] = values
        }
        return preset
    }

    /// false until the desk sent every value `part` saves: Save waits for the parts that are ticked.
    public func isReadForPreset(_ part: PresetPart, of strip: StripID) -> Bool {
        capture(strip, parts: [part], name: "", matchWords: []) != nil
    }

    private func values(of part: PresetPart, on strip: StripID) -> [String: PresetValue]? {
        var values: [String: PresetValue] = [:]
        for spec in part.specs(on: strip, headamp: headamp(of: strip)) {
            guard let value = saved(spec) else { return nil }
            values[PresetPart.path(of: spec, on: strip)] = value
        }
        return values
    }

    private func saved(_ spec: ParamSpec) -> PresetValue? {
        guard let real = value(spec) else { return nil }
        switch spec.scale {
        case .toggle: return .flag(real == 1)
        case .choice(let options): return options.indices.contains(Int(real)) ? .option(options[Int(real)]) : nil
        default: return .number(Self.rounded(real))
        }
    }

    /// Rounded to what a person would type: the desk's steps are far coarser than four digits, so the same step comes
    /// back on loading.
    private static func rounded(_ value: Double) -> Double {
        guard value.isFinite, value != 0 else { return value }
        let unit = pow(10, floor(log10(abs(value))) - 3)
        return (value / unit).rounded() * unit
    }
}

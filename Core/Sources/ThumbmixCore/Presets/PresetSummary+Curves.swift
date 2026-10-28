import Foundation

/// A preset's gate as its transfer curve draws it: what `TransferCurve.gateOutput` needs, read from the preset.
public struct PresetGateCurve: Equatable, Sendable {
    public let mode: TransferCurve.GateMode
    public let threshold: Double
    public let range: Double
    public let isOn: Bool

    public func output(_ input: Double) -> Double {
        TransferCurve.gateOutput(input, mode: mode, threshold: threshold, range: range)
    }
}

/// A preset's comp as `TransferCurve.dynamicsOutput` draws it.
public struct PresetCompCurve: Equatable, Sendable {
    public let isExpander: Bool
    public let threshold: Double
    public let ratio: Double
    public let knee: Double
    public let makeup: Double
    public let mix: Double
    public let isOn: Bool

    public func output(_ input: Double) -> Double {
        TransferCurve.dynamicsOutput(
            input, isExpander: isExpander, threshold: threshold, ratio: ratio, knee: knee, makeup: makeup, mix: mix)
    }
}

/// As `eqCurve`: the curve the part *is*, whatever its switch holds; nil when the preset lacks a value the curve needs.
extension PresetSummary {
    public static func gateCurve(_ preset: Preset) -> PresetGateCurve? {
        let reader = PresetReader(preset, .gate, .current)
        guard let name = reader.option("gate/mode"), let index = Catalog.gateModes.firstIndex(of: name),
            let mode = TransferCurve.GateMode(rawValue: index), let threshold = reader.number("gate/thr"),
            let range = reader.number("gate/range")
        else { return nil }
        return PresetGateCurve(mode: mode, threshold: threshold, range: range, isOn: reader.flag("gate/on") ?? true)
    }

    public static func compCurve(_ preset: Preset) -> PresetCompCurve? {
        let reader = PresetReader(preset, .comp, .current)
        guard let mode = reader.option("dyn/mode"), let threshold = reader.number("dyn/thr"),
            let ratio = reader.option("dyn/ratio").flatMap(Double.init), let knee = reader.number("dyn/knee"),
            let makeup = reader.number("dyn/mgain"), let mix = reader.number("dyn/mix")
        else { return nil }
        return PresetCompCurve(
            isExpander: mode == "EXP", threshold: threshold, ratio: ratio, knee: knee, makeup: makeup, mix: mix,
            isOn: reader.flag("dyn/on") ?? true)
    }
}

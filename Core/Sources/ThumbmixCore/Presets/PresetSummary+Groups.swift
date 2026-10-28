import Foundation

/// One value on a part's All values page: its label over the number, the unit small beside it.
public struct PresetCell: Equatable, Sendable {
    public let label: String
    public let number: String
    public let unit: String
    /// A send's bus, for the name the desk gives it now.
    public let bus: StripID?
    /// The preset's values this cell shows: each one is shown exactly once.
    let paths: [String]

    init(_ label: String, _ parts: ValueParts, paths: [String], bus: StripID? = nil) {
        self.label = label
        number = parts.number
        unit = parts.unit
        self.bus = bus
        self.paths = paths
    }
}

public struct PresetGroup: Equatable, Sendable {
    public let title: String
    public let cells: [PresetCell]
}

/// One EQ band as a column of the All values table: the desk's own type name ("PEQ", "HShv"), then its values.
public struct PresetBand: Equatable, Sendable {
    public let number: Int
    public let type: String
    /// A cut has no gain or Q to shape: the page dims them.
    public let shapesLevel: Bool
    public let frequency: ValueParts
    public let gain: ValueParts
    public let q: ValueParts
    let paths: [String]
}

/// A part's All values page (round 4, 2026-10-28): its values in titled groups of two columns. A value the groups
/// don't place still shows, in a last group, so a hand-written file never hides one.
extension PresetSummary {
    public static func groups(_ preset: Preset, _ part: PresetPart, locale: Locale = .current) -> [PresetGroup] {
        let reader = PresetReader(preset, part, locale)
        let placed: [PresetGroup]
        switch part {
        case .eq: placed = [PresetGroup(title: CoreStrings.text("Low cut and EQ"), cells: reader.eqCells())]
        case .sends: placed = [PresetGroup(title: CoreStrings.text("Sends"), cells: reader.sendCells())]
        default: placed = layout(part).map { title, paths in PresetGroup(title: title, cells: reader.cells(paths)) }
        }
        let shown = Set(placed.flatMap(\.cells).flatMap(\.paths) + (part == .eq ? bands(preset).flatMap(\.paths) : []))
        let other = reader.fields.filter { !shown.contains($0.path) }.map { reader.cell($0.path) }
        let groups = placed + [PresetGroup(title: CoreStrings.text("Other"), cells: other)]
        return groups.filter { !$0.cells.isEmpty }
    }

    /// The bands the preset holds whole; a band with a value left out shows its values in the last group instead.
    public static func bands(_ preset: Preset, locale: Locale = .current) -> [PresetBand] {
        let reader = PresetReader(preset, .eq, locale)
        guard reader.strip.eqBandCount > 0 else { return [] }
        return (1...reader.strip.eqBandCount).compactMap { reader.band($0) }
    }

    private static func layout(_ part: PresetPart) -> [(String, [String])] {
        switch part {
        case .input:
            [
                (CoreStrings.text("Preamp"), ["headamp/gain", "headamp/phantom", "preamp/trim", "preamp/invert"]),
                (CoreStrings.text("Delay"), ["delay/on", "delay/time"]),
            ]
        case .gate:
            [
                (CoreStrings.text("Level"), ["gate/on", "gate/mode", "gate/thr", "gate/range"]),
                (CoreStrings.text("Timing"), ["gate/attack", "gate/hold", "gate/release"]),
                (CoreStrings.text("Key filter"), ["gate/filter/on", "gate/filter/type", "gate/filter/f"]),
            ]
        case .comp:
            [
                (CoreStrings.text("Level"), ["dyn/on", "dyn/thr", "dyn/ratio", "dyn/knee", "dyn/mgain"]),
                (CoreStrings.text("Timing"), ["dyn/attack", "dyn/hold", "dyn/release", "dyn/mix"]),
                (CoreStrings.text("How it listens"), ["dyn/mode", "dyn/det", "dyn/env", "dyn/pos", "dyn/auto"]),
                (CoreStrings.text("Key filter"), ["dyn/filter/on", "dyn/filter/type", "dyn/filter/f"]),
            ]
        case .mix: [(CoreStrings.text("Mix"), ["mix/fader", "mix/pan"])]
        case .eq, .sends: []
        }
    }
}

extension PresetReader {
    func cells(_ paths: [String]) -> [PresetCell] {
        paths.filter { field($0) != nil }.map(cell)
    }

    func cell(_ path: String) -> PresetCell {
        PresetCell(label(path), parts(path) ?? ValueParts(number: "—"), paths: [path])
    }

    /// The low cut is one cell, its frequency or "Off", beside the EQ's own switch.
    func eqCells() -> [PresetCell] {
        let lowCut = ["preamp/hpon", "preamp/hpf"].filter { field($0) != nil }
        var cells: [PresetCell] = []
        if !lowCut.isEmpty {
            let value =
                flag("preamp/hpon") == false ? ValueParts(number: CoreStrings.text("Off")) : parts("preamp/hpf")
            cells.append(PresetCell(CoreStrings.text("Low cut"), value ?? ValueParts(number: "—"), paths: lowCut))
        }
        return cells + self.cells(["eq/on"])
    }

    /// One cell per bus: its level, and where it isn't after the fader, its tap; "Off" for a send that's off.
    func sendCells() -> [PresetCell] {
        PresetSend.all(in: self).map { send in
            let value =
                send.isOn
                ? ValueParts(number: send.level.number, unit: send.tap.map { send.level.unit + " · " + $0 } ?? send.level.unit)
                : ValueParts(number: CoreStrings.text("Off"))
            return PresetCell(send.bus.defaultName, value, paths: send.paths, bus: send.bus)
        }
    }

    func band(_ number: Int) -> PresetBand? {
        let paths = ["type", "f", "g", "q"].map { "eq/\(number)/" + $0 }
        guard let name = option(paths[0]), let frequency = parts(paths[1]), let gain = parts(paths[2]),
            let q = parts(paths[3])
        else { return nil }
        let type = EQFilterType(deskName: name)
        return PresetBand(
            number: number, type: name, shapesLevel: type?.shapesLevel ?? true, frequency: frequency, gain: gain, q: q,
            paths: paths)
    }
}

import Foundation

/// A named set of strip settings an engineer saved: per part, the desk's own values by the control's path under the
/// strip ("gate/thr", "eq/2/f", "headamp/gain"), in real units and the desk's option names, so a file reads and edits
/// by hand. It is a Reset's list (`Catalog.gateDefaults`) with values read from the desk instead of fixed ones.
public struct Preset: Equatable, Sendable {
    public var name: String
    /// Words a strip's name is matched against (`PresetMatching`). Empty fits nothing.
    public var matchWords: [String]
    /// The strip it was saved from: the layout its EQ and sends belong to.
    public var stripKind: StripKind
    /// A part is missing where the preset holds none.
    public var values: [PresetPart: [String: PresetValue]] = [:]

    /// The parts it holds, in the order the app lists them.
    public var parts: [PresetPart] { PresetPart.allCases.filter(holds) }

    public func holds(_ part: PresetPart) -> Bool { values[part] != nil }
}

/// One saved value: a number in the control's real unit (−∞ is written "-inf"), a switch, or a choice by the desk's
/// own name for it.
public enum PresetValue: Equatable, Sendable {
    case number(Double)
    case flag(Bool)
    case option(String)
}

/// What a preset's parts are called in the app and in its tick lists.
public enum PresetPart: String, CaseIterable, Identifiable, Sendable {
    case input, eq, gate, comp, mix, sends

    public var id: Self { self }

    public var title: String {
        switch self {
        case .input: CoreStrings.text("Input")
        case .eq: CoreStrings.text("EQ")
        case .gate: CoreStrings.text("Gate")
        case .comp: CoreStrings.text("Comp")
        case .mix: CoreStrings.text("Mix")
        case .sends: CoreStrings.text("Sends")
        }
    }

    /// Whether the strip has this part at all: an aux in has no gate, a bus no Input tab, a matrix no sends.
    public func exists(on strip: StripID) -> Bool {
        guard strip.kind != .dca else { return false }
        switch self {
        case .input: return ChannelTab.tabs(for: strip.kind).contains(.input)
        case .eq: return strip.eqBandCount > 0
        case .gate: return strip.hasGate
        case .comp: return strip.hasDynamics
        case .mix: return true
        case .sends: return strip.kind.sendTarget != nil
        }
    }

    /// The controls this part saves and loads on `strip`, as a Reset lists them. Nothing that names another strip (a
    /// key source); gain and 48V only where `headamp` feeds the strip.
    func specs(on strip: StripID, headamp: Int?) -> [ParamSpec] {
        guard exists(on: strip) else { return [] }
        switch self {
        case .input:
            let preamp = headamp.map { [Catalog.headampGain($0), Catalog.headampPhantom($0)] } ?? []
            return preamp + [Catalog.trim(strip)] + [Catalog.invert(strip)].compactMap { $0 } + (Catalog.delay(strip)?.all ?? [])
        case .eq:
            return [Catalog.eqOn(strip)] + (Catalog.lowCut(strip)?.all ?? [])
                + (1...strip.eqBandCount).flatMap { Catalog.eqBand(strip, $0).all }
        case .gate: return Catalog.gate(strip).all + Self.filter(Catalog.gateKey(strip))
        case .comp:
            return Catalog.dynamics(strip).all + Self.filter(Catalog.dynamicsKey(strip))
                + [Catalog.dynamicsPosition(strip)].compactMap { $0 }
        case .mix: return [Catalog.fader(strip)] + [Catalog.pan(strip)].compactMap { $0 }
        case .sends: return Self.sendSpecs(strip)
        }
    }

    private static func filter(_ key: KeySpecs) -> [ParamSpec] { [key.filterOn, key.filterType, key.filterFrequency] }

    private static func sendSpecs(_ strip: StripID) -> [ParamSpec] {
        guard let kind = strip.kind.sendTarget else { return [] }
        return StripID.all(kind).flatMap { target in
            [Catalog.sendLevel(from: strip, to: target), Catalog.sendOn(from: strip, to: target)]
                + [Catalog.sendTap(from: strip, to: target)].compactMap { $0 }
        }
    }

    /// A control's path under its strip: the address without the strip's prefix, or "headamp/gain" for the preamp,
    /// whose address names the input instead.
    static func path(of spec: ParamSpec, on strip: StripID) -> String {
        let prefix = strip.prefix + "/"
        if spec.address.hasPrefix(prefix) { return String(spec.address.dropFirst(prefix.count)) }
        return "headamp/" + (spec.address.split(separator: "/").last.map(String.init) ?? "")
    }
}

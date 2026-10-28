import Foundation

/// One line beside a part's graph on the preset page: "Threshold −18 dB".
public struct PresetLine: Equatable, Sendable {
    public let label: String
    public let value: String
    /// A send's bus: the page adds the name the desk gives it now, since a send loads by number.
    public let bus: StripID?

    init(_ label: String, _ value: String, bus: StripID? = nil) {
        self.label = label
        self.value = value
        self.bus = bus
    }
}

/// The preset page's overview (round 4, 2026-10-28): per part the few values that change its sound most, beside its
/// graph. Everything else is on the part's All values page (`groups`).
extension PresetSummary {
    /// The sends a line names before the rest is summed up in one.
    static let shownSends = 3

    public static func overview(_ preset: Preset, _ part: PresetPart, locale: Locale = .current) -> [PresetLine] {
        let reader = PresetReader(preset, part, locale)
        switch part {
        case .input:
            return reader.lines(["headamp/gain", "headamp/phantom", "preamp/trim", "preamp/invert"]) + reader.delayLine()
        case .eq: return reader.offLine("eq/on") + reader.lowCutLine() + reader.bandLines()
        case .gate:
            return reader.offLine("gate/on") + reader.lines(["gate/thr", "gate/range", "gate/release"])
                + reader.keyFilterLine("gate/")
        case .comp: return reader.offLine("dyn/on") + reader.lines(["dyn/ratio", "dyn/thr", "dyn/mgain", "dyn/release"])
        case .mix: return reader.lines(["mix/fader", "mix/pan"])
        case .sends: return sendLines(PresetSend.all(in: reader))
        }
    }

    /// The first buses that send, by number; then one line for the rest: "Off", or how many of them send.
    private static func sendLines(_ sends: [PresetSend]) -> [PresetLine] {
        let shown = Array(sends.filter(\.isSending).prefix(shownSends))
        let lines = shown.map { PresetLine($0.bus.defaultName, $0.text, bus: $0.bus) }
        let rest = sends.filter { send in !shown.contains { $0.bus == send.bus } }
        guard !rest.isEmpty else { return lines }
        if shown.isEmpty {
            return [PresetLine(CoreStrings.text("All buses"), CoreStrings.text("Off"))]
        }
        let on = rest.filter(\.isSending).count
        return lines + [PresetLine(CoreStrings.text("Other buses"), on == 0 ? CoreStrings.text("Off") : CoreStrings.text("\(on) on"))]
    }
}

extension PresetReader {
    func lines(_ paths: [String]) -> [PresetLine] {
        paths.compactMap { path in parts(path).map { PresetLine(label(path), $0.text) } }
    }

    /// A part saved switched off says so first: loading it switches the part off.
    func offLine(_ path: String) -> [PresetLine] {
        flag(path) == false ? [PresetLine(label(path), CoreStrings.text("Off"))] : []
    }

    func delayLine() -> [PresetLine] {
        guard let on = flag("delay/on") else { return lines(["delay/time"]) }
        guard on else { return [PresetLine(label("delay/on"), CoreStrings.text("Off"))] }
        return [PresetLine(label("delay/on"), parts("delay/time")?.text ?? CoreStrings.text("On"))]
    }

    func lowCutLine() -> [PresetLine] {
        let name = CoreStrings.text("Low cut")
        if flag("preamp/hpon") == false { return [PresetLine(name, CoreStrings.text("Off"))] }
        return parts("preamp/hpf").map { [PresetLine(name, $0.text)] } ?? []
    }

    /// A band named by its frequency, with its gain; one at 0 dB does nothing and is left out. A cut has no gain, so it
    /// shows its type.
    func bandLines() -> [PresetLine] {
        (1...max(strip.eqBandCount, 1)).compactMap { band in
            let prefix = "eq/\(band)/"
            guard let type = option(prefix + "type").flatMap(EQFilterType.init(deskName:)),
                let frequency = parts(prefix + "f")
            else { return nil }
            guard type.shapesLevel else { return PresetLine(frequency.text, type.deskName) }
            guard let gain = number(prefix + "g"), abs(gain) >= 0.125, let text = parts(prefix + "g") else { return nil }
            return PresetLine(frequency.text, text.text)
        }
    }

    /// "101.4 Hz LC12": the frequency and the desk's own name for the filter, only while it's on.
    func keyFilterLine(_ prefix: String) -> [PresetLine] {
        guard flag(prefix + "filter/on") == true, let frequency = parts(prefix + "filter/f"),
            let type = option(prefix + "filter/type")
        else { return [] }
        return [PresetLine(CoreStrings.text("Key filter"), frequency.text + " " + type)]
    }
}

extension EQFilterType {
    init?(deskName: String) {
        guard let type = Self.allCases.first(where: { $0.deskName == deskName }) else { return nil }
        self = type
    }
}

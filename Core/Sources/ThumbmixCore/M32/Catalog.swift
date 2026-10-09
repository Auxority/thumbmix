import Foundation

/// Every M32 parameter Thumbmix v1 touches. Ranges are from Maillot's protocol doc v4.09 (p.25-43).
public enum Catalog {
    public static let gateModes = ["EXP2", "EXP3", "EXP4", "GATE", "DUCK"]
    public static let dynamicsModes = ["COMP", "EXP"]
    public static let dynamicsDetectors = ["PEAK", "RMS"]
    public static let dynamicsEnvelopes = ["LIN", "LOG"]
    public static let ratios = [
        "1.1", "1.3", "1.5", "2.0", "2.5", "3.0", "4.0", "5.0", "7.0", "10", "20", "100",
    ]
    public static let eqTypes = ["LCut", "LShv", "PEQ", "VEQ", "HShv", "HCut"]
    public static let mainEQTypes =
        eqTypes + ["BU6", "BU12", "BS12", "LR12", "BU18", "BU24", "BS24", "LR24"]

    private static let hold = ParamScale.log(min: 0.02, max: 2000, steps: 101)
    private static let release = ParamScale.log(min: 5, max: 4000, steps: 101)
    private static let attack = ParamScale.linear(min: 0, max: 120, step: 1)

    public static func fader(_ strip: StripID) -> ParamSpec {
        ParamSpec(strip.fader, CoreStrings.text("Fader"), .fader, .decibels, reset: 0)
    }

    /// `on` = 1 means the strip is live; mute is `on` = 0.
    public static func on(_ strip: StripID) -> ParamSpec {
        ParamSpec(strip.on, CoreStrings.text("On"), .toggle, .plain)
    }

    public static func pan(_ strip: StripID) -> ParamSpec? {
        strip.pan.map {
            ParamSpec($0, CoreStrings.text("Pan"), .linear(min: -100, max: 100, step: 2), .pan, reset: 0)
        }
    }

    public static func trim(_ strip: StripID) -> ParamSpec {
        ParamSpec(
            strip.prefix + "/preamp/trim", CoreStrings.text("Trim"),
            .linear(min: -18, max: 18, step: 0.25), .decibels, reset: 0)
    }

    /// The channel's high-pass filter (doc p.25). The desk keeps it in the preamp section; only input
    /// channels have one, so the app shows it with the EQ bands of inputs only.
    public static func lowCut(_ strip: StripID) -> LowCutSpecs? {
        guard strip.kind == .input else { return nil }
        let p = strip.prefix + "/preamp/"
        return LowCutSpecs(
            on: ParamSpec(p + "hpon", CoreStrings.text("Low cut"), .toggle, .plain),
            frequency: ParamSpec(p + "hpf", CoreStrings.text("Freq"), .log(min: 20, max: 400, steps: 101), .hertz),
            slope: ParamSpec(
                p + "hpslope", CoreStrings.text("Slope"), .choice(["12 dB/oct", "18 dB/oct", "24 dB/oct"]), .plain)
        )
    }

    public static func headampGain(_ index: Int) -> ParamSpec {
        ParamSpec(
            headamp(index) + "/gain", CoreStrings.text("Gain"), .linear(min: -12, max: 60, step: 0.5),
            .decibels, reset: 0)
    }

    /// Only input channels have a delay (doc p.25).
    public static func delay(_ strip: StripID) -> DelaySpecs? {
        guard strip.kind == .input else { return nil }
        let p = strip.prefix + "/delay/"
        return DelaySpecs(
            on: ParamSpec(p + "on", CoreStrings.text("Delay"), .toggle, .plain),
            time: ParamSpec(
                p + "time", CoreStrings.text("Time"), .linear(min: 0.3, max: 500, step: 0.1), .delayTime,
                reset: 0.3)
        )
    }

    public static func headampPhantom(_ index: Int) -> ParamSpec {
        ParamSpec(headamp(index) + "/phantom", CoreStrings.text("48V"), .toggle, .plain)
    }

    /// The console answers which headamp (0-127) feeds input `n`, or -1 for internal sources (doc p.43).
    public static func headampIndex(forInput n: Int) -> String {
        "/-ha/" + String(format: "%02d", n - 1) + "/index"
    }

    public static let headampIndexAddresses = (1...32).map(headampIndex(forInput:))

    public static func gate(_ strip: StripID) -> GateSpecs {
        let p = strip.prefix + "/gate/"
        return GateSpecs(
            on: ParamSpec(p + "on", CoreStrings.text("Gate"), .toggle, .plain),
            mode: ParamSpec(
                p + "mode", CoreStrings.text("Mode"), .choice(gateModes), .plain,
                optionNames: [
                    CoreStrings.text("Expander 1:2"), CoreStrings.text("Expander 1:3"),
                    CoreStrings.text("Expander 1:4"), CoreStrings.text("Gate"), CoreStrings.text("Ducker"),
                ]),
            threshold: ParamSpec(
                p + "thr", CoreStrings.text("Threshold"), .linear(min: -80, max: 0, step: 0.5), .decibels),
            range: ParamSpec(
                p + "range", CoreStrings.text("Range"), .linear(min: 3, max: 60, step: 1), .decibelAmount),
            attack: ParamSpec(p + "attack", CoreStrings.text("Attack"), attack, .milliseconds),
            hold: ParamSpec(p + "hold", CoreStrings.text("Hold"), hold, .milliseconds),
            release: ParamSpec(p + "release", CoreStrings.text("Release"), release, .milliseconds)
        )
    }

    public static func dynamics(_ strip: StripID) -> DynamicsSpecs {
        let p = strip.prefix + "/dyn/"
        return DynamicsSpecs(
            on: ParamSpec(p + "on", CoreStrings.text("Comp"), .toggle, .plain),
            mode: ParamSpec(
                p + "mode", CoreStrings.text("Mode"), .choice(dynamicsModes), .plain,
                optionNames: [CoreStrings.text("Compressor"), CoreStrings.text("Expander")]),
            threshold: ParamSpec(
                p + "thr", CoreStrings.text("Threshold"), .linear(min: -60, max: 0, step: 0.5), .decibels),
            ratio: ParamSpec(
                p + "ratio", CoreStrings.text("Ratio"), .choice(ratios), .ratio,
                reset: ratios.firstIndex(of: "3.0").map(Double.init)),
            knee: ParamSpec(
                p + "knee", CoreStrings.text("Knee"), .linear(min: 0, max: 5, step: 1), .plain),
            attack: ParamSpec(p + "attack", CoreStrings.text("Attack"), attack, .milliseconds),
            hold: ParamSpec(p + "hold", CoreStrings.text("Hold"), hold, .milliseconds),
            release: ParamSpec(p + "release", CoreStrings.text("Release"), release, .milliseconds),
            makeup: ParamSpec(
                p + "mgain", CoreStrings.text("Makeup gain"), .linear(min: 0, max: 24, step: 0.5),
                .decibelAmount, reset: 0),
            // RMS follows the signal's average level, PEAK its peaks: "average level" says that without the maths.
            detector: ParamSpec(
                p + "det", CoreStrings.text("Detector"), .choice(dynamicsDetectors), .plain,
                optionNames: [CoreStrings.text("Peak level"), CoreStrings.text("Average level")]),
            envelope: ParamSpec(
                p + "env", CoreStrings.text("Envelope"), .choice(dynamicsEnvelopes), .plain,
                optionNames: [CoreStrings.text("Linear"), CoreStrings.text("Logarithmic")])
        )
    }

    public static func eqOn(_ strip: StripID) -> ParamSpec {
        ParamSpec(strip.prefix + "/eq/on", CoreStrings.text("EQ"), .toggle, .plain)
    }

    /// A band row's double-tap restores what Reset bands writes, at once like a double-tap on the graph's point.
    public static func eqBand(_ strip: StripID, _ band: Int) -> EQBandSpecs {
        let p = strip.prefix + "/eq/\(band)/"
        let types = [.matrix, .mainStereo, .mainMono].contains(strip.kind) ? mainEQTypes : eqTypes
        let target = eqDefaults(strip).flatMap { $0.indices.contains(band - 1) ? $0[band - 1] : nil }
        return EQBandSpecs(
            type: ParamSpec(p + "type", CoreStrings.text("Type"), .choice(types), .plain),
            frequency: ParamSpec(
                p + "f", CoreStrings.text("Freq"), .log(min: 20, max: 20_000, steps: 201), .hertz,
                reset: target?.frequency),
            gain: ParamSpec(
                p + "g", CoreStrings.text("Gain"), .linear(min: -15, max: 15, step: 0.25), .decibels,
                reset: 0),
            q: ParamSpec(
                p + "q", CoreStrings.text("Q"), .log(min: 10, max: 0.3, steps: 72), .plain, reset: target?.q)
        )
    }

    /// The engineer's EQ starting points, restored by Reset bands and a row's double-tap: PEQs at Q 1.7, 0 dB.
    /// Six-band strips use the desk's steps nearest the engineer's 55.1, 152, 418, 1150, 3170 and 8730 Hz;
    /// compare them with the real desk (TODO). PEQ is type 2 in both type lists.
    public static func eqDefaults(_ strip: StripID) -> [EQBandState]? {
        let frequencies: [Double] =
            switch strip.eqBandCount {
            case 4: [91.4, 418, 1910, 8730]
            case 6: [54.5, 153.5, 418, 1140, 3210, 8730]
            default: []
            }
        guard !frequencies.isEmpty else { return nil }
        return frequencies.map { EQBandState(typeIndex: 2, frequency: $0, gain: 0, q: 1.7) }
    }

    /// `eqDefaults` for one band as the desk's arguments, each snapped to the nearest step its scale has.
    public static func eqDefaultArguments(_ strip: StripID, _ band: Int) -> [(address: String, argument: OSCArgument)] {
        guard let defaults = eqDefaults(strip), defaults.indices.contains(band - 1) else { return [] }
        let target = defaults[band - 1]
        let specs = eqBand(strip, band)
        let values = [
            (specs.type, Double(target.typeIndex)), (specs.frequency, target.frequency), (specs.gain, target.gain),
            (specs.q, target.q),
        ]
        return values.map { spec, value in
            (spec.address, spec.scale.argument(fromNormalized: spec.scale.normalized(forValue: value)))
        }
    }

    /// Cut filters (LCut, HCut, the mains' BU6…LR24) have no level to shape, so Gain and Q do nothing there.
    /// The doc lists gain and Q for every type without saying so: assumed, to check on the desk (TODO).
    public static func eqTypeShapesLevel(_ name: String) -> Bool { ["LShv", "PEQ", "VEQ", "HShv"].contains(name) }

    /// `target` is a bus for inputs, aux ins and FX returns, a matrix for buses and mains (`StripKind.sendTarget`).
    public static func sendLevel(from strip: StripID, to target: StripID) -> ParamSpec {
        ParamSpec(sendPrefix(strip, target) + "/level", target.defaultName, .sendLevel, .decibels, reset: 0)
    }

    public static func sendOn(from strip: StripID, to target: StripID) -> ParamSpec {
        ParamSpec(sendPrefix(strip, target) + "/on", CoreStrings.text("On"), .toggle, .plain)
    }

    /// Every address the mirror reads on connect; the mirror goes live once all have answered.
    public static func syncAddresses() -> [String] {
        StripKind.allCases.flatMap(StripID.all).flatMap(addresses(of:)) + headampAddresses() + rtaAddresses
            + linkAddresses
    }

    /// Every pair's link switch and the four Link Preferences: they decide how the overview and tabs look.
    public static let linkAddresses =
        StripKind.allCases.flatMap(StripID.all).filter { $0 == $0.oddSide }.compactMap(\.linkAddress)
        + LinkSection.allCases.map(\.preferenceAddress)

    /// Read on connect so the desk's own RTA setting is known before the app borrows it.
    private static let rtaAddresses = [RTA.source, RTA.position]

    static func addresses(of strip: StripID) -> [String] {
        [strip.name, strip.color, strip.icon, strip.fader, strip.on] + [strip.pan, strip.dcaMask].compactMap { $0 }
            + inputAddresses(strip) + dynamicsAddresses(strip) + eqAddresses(strip) + sendAddresses(strip)
    }

    private static func inputAddresses(_ strip: StripID) -> [String] {
        guard strip.hasGate else { return [] }
        return [trim(strip).address] + gate(strip).all.map(\.address) + [headampIndex(forInput: strip.number)]
            + (lowCut(strip)?.all.map(\.address) ?? []) + (delay(strip)?.all.map(\.address) ?? [])
    }

    private static func dynamicsAddresses(_ strip: StripID) -> [String] {
        strip.hasDynamics ? dynamics(strip).all.map(\.address) : []
    }

    private static func eqAddresses(_ strip: StripID) -> [String] {
        guard strip.eqBandCount > 0 else { return [] }
        return [eqOn(strip).address] + (1...strip.eqBandCount).flatMap { eqBand(strip, $0).all.map(\.address) }
    }

    private static func sendAddresses(_ strip: StripID) -> [String] {
        guard let target = strip.kind.sendTarget else { return [] }
        return StripID.all(target).flatMap {
            [sendLevel(from: strip, to: $0).address, sendOn(from: strip, to: $0).address]
        }
    }

    private static func headampAddresses() -> [String] {
        (0..<128).flatMap { [headampGain($0).address, headampPhantom($0).address] }
    }

    /// The values a stale display would hurt most: what each strip is called and where its fader and mute sit.
    /// The RTA setting is audited too: the doc doesn't say a change on the desk is pushed, and releasing
    /// the RTA must not overwrite a choice the engineer made on the desk meanwhile.
    public static func auditAddresses() -> [String] {
        rtaAddresses + linkAddresses
            + StripKind.allCases.flatMap(StripID.all).flatMap { strip in
                [strip.name, strip.color, strip.fader, strip.on] + [strip.pan].compactMap { $0 }
            }
    }

    private static func headamp(_ index: Int) -> String {
        "/headamp/" + String(format: "%03d", index)
    }
    private static func sendPrefix(_ strip: StripID, _ target: StripID) -> String {
        strip.prefix + "/mix/" + String(format: "%02d", target.number)
    }
}

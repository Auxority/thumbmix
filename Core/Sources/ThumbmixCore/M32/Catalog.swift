import Foundation

/// Every M32 parameter Thumbmix v1 touches. Ranges are from Maillot's protocol doc v4.09 (p.25-43).
public enum Catalog {
    public static let gateModes = ["EXP2", "EXP3", "EXP4", "GATE", "DUCK"]
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

    /// No reset: a double-tap jumping preamp gain could cause feedback.
    public static func headampGain(_ index: Int) -> ParamSpec {
        ParamSpec(
            headamp(index) + "/gain", CoreStrings.text("Gain"), .linear(min: -12, max: 60, step: 0.5),
            .decibels)
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
            mode: ParamSpec(p + "mode", CoreStrings.text("Mode"), .choice(gateModes), .plain),
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
            threshold: ParamSpec(
                p + "thr", CoreStrings.text("Threshold"), .linear(min: -60, max: 0, step: 0.5), .decibels),
            ratio: ParamSpec(p + "ratio", CoreStrings.text("Ratio"), .choice(ratios), .ratio),
            knee: ParamSpec(
                p + "knee", CoreStrings.text("Knee"), .linear(min: 0, max: 5, step: 1), .plain),
            attack: ParamSpec(p + "attack", CoreStrings.text("Attack"), attack, .milliseconds),
            hold: ParamSpec(p + "hold", CoreStrings.text("Hold"), hold, .milliseconds),
            release: ParamSpec(p + "release", CoreStrings.text("Release"), release, .milliseconds),
            makeup: ParamSpec(
                p + "mgain", CoreStrings.text("Makeup"), .linear(min: 0, max: 24, step: 0.5), .decibelAmount
            )
        )
    }

    public static func eqOn(_ strip: StripID) -> ParamSpec {
        ParamSpec(strip.prefix + "/eq/on", CoreStrings.text("EQ"), .toggle, .plain)
    }

    public static func eqBand(_ strip: StripID, _ band: Int) -> EQBandSpecs {
        let p = strip.prefix + "/eq/\(band)/"
        let types = [.mainStereo, .mainMono].contains(strip.kind) ? mainEQTypes : eqTypes
        return EQBandSpecs(
            type: ParamSpec(p + "type", CoreStrings.text("Type"), .choice(types), .plain),
            frequency: ParamSpec(
                p + "f", CoreStrings.text("Freq"), .log(min: 20, max: 20_000, steps: 201), .hertz),
            gain: ParamSpec(
                p + "g", CoreStrings.text("Gain"), .linear(min: -15, max: 15, step: 0.25), .decibels,
                reset: 0),
            q: ParamSpec(p + "q", CoreStrings.text("Q"), .log(min: 10, max: 0.3, steps: 72), .plain)
        )
    }

    public static func sendLevel(from strip: StripID, toBus bus: Int) -> ParamSpec {
        ParamSpec(sendPrefix(strip, bus) + "/level", CoreStrings.text("Bus \(bus)"), .sendLevel, .decibels, reset: 0)
    }

    public static func sendOn(from strip: StripID, toBus bus: Int) -> ParamSpec {
        ParamSpec(sendPrefix(strip, bus) + "/on", CoreStrings.text("On"), .toggle, .plain)
    }

    /// Every address the mirror reads on connect, names first so the overview fills in early.
    public static func syncAddresses() -> [String] {
        StripKind.allCases.flatMap(StripID.all).flatMap(addresses(of:)) + headampAddresses()
    }

    private static func addresses(of strip: StripID) -> [String] {
        [strip.name, strip.color, strip.fader, strip.on] + [strip.pan, strip.dcaMask].compactMap { $0 }
            + inputAddresses(strip) + dynamicsAddresses(strip) + eqAddresses(strip) + sendAddresses(strip)
    }

    private static func inputAddresses(_ strip: StripID) -> [String] {
        guard strip.hasGate else { return [] }
        return [trim(strip).address] + gate(strip).all.map(\.address) + [headampIndex(forInput: strip.number)]
    }

    private static func dynamicsAddresses(_ strip: StripID) -> [String] {
        strip.hasDynamics ? dynamics(strip).all.map(\.address) : []
    }

    private static func eqAddresses(_ strip: StripID) -> [String] {
        guard strip.eqBandCount > 0 else { return [] }
        return [eqOn(strip).address] + (1...strip.eqBandCount).flatMap { eqBand(strip, $0).all.map(\.address) }
    }

    private static func sendAddresses(_ strip: StripID) -> [String] {
        guard strip.sendsToBuses else { return [] }
        return (1...16).flatMap { [sendLevel(from: strip, toBus: $0).address, sendOn(from: strip, toBus: $0).address] }
    }

    private static func headampAddresses() -> [String] {
        (0..<128).flatMap { [headampGain($0).address, headampPhantom($0).address] }
    }

    /// The values a stale display would hurt most: what each strip is called and where its fader and mute sit.
    public static func auditAddresses() -> [String] {
        StripKind.allCases.flatMap(StripID.all).flatMap { strip in
            [strip.name, strip.color, strip.fader, strip.on] + [strip.pan].compactMap { $0 }
        }
    }

    private static func headamp(_ index: Int) -> String {
        "/headamp/" + String(format: "%03d", index)
    }
    private static func sendPrefix(_ strip: StripID, _ bus: Int) -> String {
        strip.prefix + "/mix/" + String(format: "%02d", bus)
    }
}

import Foundation

/// A named set of strip settings an engineer saved, in real units (dB, Hz, ms) and the desk's option names, so a
/// file reads and edits by hand. A part is nil where the preset holds none.
public struct Preset: Equatable, Sendable {
    public var name: String
    /// Words a strip's name is matched against (`PresetMatching`). Empty fits nothing.
    public var matchWords: [String]
    /// The strip it was saved from: the layout its EQ and sends belong to.
    public var stripKind: StripKind
    public var input: InputPart?
    public var eq: EQPart?
    public var gate: GatePart?
    public var comp: CompPart?
    public var mix: MixPart?
    /// By the target's number as text ("3" = bus 3 for an input, matrix 3 for a bus).
    public var sends: [String: SendPart]?

    public init(
        name: String, matchWords: [String], stripKind: StripKind, input: InputPart? = nil, eq: EQPart? = nil,
        gate: GatePart? = nil, comp: CompPart? = nil, mix: MixPart? = nil, sends: [String: SendPart]? = nil
    ) {
        self.name = name
        self.matchWords = matchWords
        self.stripKind = stripKind
        self.input = input
        self.eq = eq
        self.gate = gate
        self.comp = comp
        self.mix = mix
        self.sends = sends
    }

    /// The parts it holds, in the order the app lists them.
    public var parts: [PresetPart] { PresetPart.allCases.filter(holds) }

    public func holds(_ part: PresetPart) -> Bool {
        switch part {
        case .input: input != nil
        case .eq: eq != nil
        case .gate: gate != nil
        case .comp: comp != nil
        case .mix: mix != nil
        case .sends: sends != nil
        }
    }
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
}

/// Gain and 48V belong to the preamp, shared by every strip on that input; a strip without a preamp loads the rest.
public struct InputPart: Equatable, Sendable, Codable {
    public var gainDb: Double?
    public var phantom: Bool?
    public var trimDb: Double?
    public var polarityFlipped: Bool?
    public var delayOn: Bool?
    public var delayMs: Double?

    public init(
        gainDb: Double? = nil, phantom: Bool? = nil, trimDb: Double? = nil, polarityFlipped: Bool? = nil,
        delayOn: Bool? = nil, delayMs: Double? = nil
    ) {
        self.gainDb = gainDb
        self.phantom = phantom
        self.trimDb = trimDb
        self.polarityFlipped = polarityFlipped
        self.delayOn = delayOn
        self.delayMs = delayMs
    }
}

public struct EQPart: Equatable, Sendable, Codable {
    public var on: Bool
    /// Inputs only.
    public var lowCut: LowCutPart?
    public var bands: [BandPart]

    public init(on: Bool, lowCut: LowCutPart?, bands: [BandPart]) {
        self.on = on
        self.lowCut = lowCut
        self.bands = bands
    }
}

public struct LowCutPart: Equatable, Sendable, Codable {
    public var on: Bool
    public var hz: Double

    public init(on: Bool, hz: Double) {
        self.on = on
        self.hz = hz
    }
}

public struct BandPart: Equatable, Sendable, Codable {
    /// The desk's name for the filter: "PEQ", "LShv", "HShv"...
    public var type: String
    public var hz: Double
    public var db: Double
    public var q: Double

    public init(type: String, hz: Double, db: Double, q: Double) {
        self.type = type
        self.hz = hz
        self.db = db
        self.q = q
    }
}

/// The key filter only: the key source names another strip on this desk, so it stays out.
public struct KeyFilterPart: Equatable, Sendable, Codable {
    public var on: Bool
    public var type: String
    public var hz: Double

    public init(on: Bool, type: String, hz: Double) {
        self.on = on
        self.type = type
        self.hz = hz
    }
}

public struct GatePart: Equatable, Sendable, Codable {
    public var on: Bool
    public var mode: String
    public var thresholdDb: Double
    public var rangeDb: Double
    public var attackMs: Double
    public var holdMs: Double
    public var releaseMs: Double
    public var keyFilter: KeyFilterPart?

    public init(
        on: Bool, mode: String, thresholdDb: Double, rangeDb: Double, attackMs: Double, holdMs: Double,
        releaseMs: Double, keyFilter: KeyFilterPart?
    ) {
        self.on = on
        self.mode = mode
        self.thresholdDb = thresholdDb
        self.rangeDb = rangeDb
        self.attackMs = attackMs
        self.holdMs = holdMs
        self.releaseMs = releaseMs
        self.keyFilter = keyFilter
    }
}

public struct CompPart: Equatable, Sendable, Codable {
    public var on: Bool
    public var mode: String
    public var thresholdDb: Double
    public var ratio: String
    public var knee: Double
    public var attackMs: Double
    public var holdMs: Double
    public var releaseMs: Double
    public var makeupDb: Double
    public var mixPercent: Double
    public var detector: String
    public var envelope: String
    public var auto: Bool
    /// "PRE" or "POST": before or after the EQ.
    public var position: String
    public var keyFilter: KeyFilterPart?

    public init(
        on: Bool, mode: String, thresholdDb: Double, ratio: String, knee: Double, attackMs: Double, holdMs: Double,
        releaseMs: Double, makeupDb: Double, mixPercent: Double, detector: String, envelope: String, auto: Bool,
        position: String, keyFilter: KeyFilterPart?
    ) {
        self.on = on
        self.mode = mode
        self.thresholdDb = thresholdDb
        self.ratio = ratio
        self.knee = knee
        self.attackMs = attackMs
        self.holdMs = holdMs
        self.releaseMs = releaseMs
        self.makeupDb = makeupDb
        self.mixPercent = mixPercent
        self.detector = detector
        self.envelope = envelope
        self.auto = auto
        self.position = position
        self.keyFilter = keyFilter
    }
}

/// `faderDb` is -∞ when the fader is all the way down (written "-inf").
public struct MixPart: Equatable, Sendable {
    public var faderDb: Double
    public var pan: Double?

    public init(faderDb: Double, pan: Double?) {
        self.faderDb = faderDb
        self.pan = pan
    }
}

public struct SendPart: Equatable, Sendable {
    public var levelDb: Double
    public var on: Bool
    /// Odd sends only: where the send is taken from the strip, by the desk's name ("POST", "EQ->").
    public var tap: String?

    public init(levelDb: Double, on: Bool, tap: String?) {
        self.levelDb = levelDb
        self.on = on
        self.tap = tap
    }
}

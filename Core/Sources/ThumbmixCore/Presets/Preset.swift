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
}

public struct EQPart: Equatable, Sendable, Codable {
    public var on: Bool
    /// Inputs only.
    public var lowCut: LowCutPart?
    public var bands: [BandPart]
}

public struct LowCutPart: Equatable, Sendable, Codable {
    public var on: Bool
    public var hz: Double
}

public struct BandPart: Equatable, Sendable, Codable {
    /// The desk's name for the filter: "PEQ", "LShv", "HShv"...
    public var type: String
    public var hz: Double
    public var db: Double
    public var q: Double
}

/// The key filter only: the key source names another strip on this desk, so it stays out.
public struct KeyFilterPart: Equatable, Sendable, Codable {
    public var on: Bool
    public var type: String
    public var hz: Double
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
}

/// `faderDb` is -∞ when the fader is all the way down (written "-inf").
public struct MixPart: Equatable, Sendable {
    public var faderDb: Double
    public var pan: Double?
}

public struct SendPart: Equatable, Sendable {
    public var levelDb: Double
    public var on: Bool
    /// Odd sends only: where the send is taken from the strip, by the desk's name ("POST", "EQ->").
    public var tap: String?
}

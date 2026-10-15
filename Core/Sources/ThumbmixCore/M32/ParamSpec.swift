public enum ParamUnit: Sendable {
    /// `decibels` is a signed level or gain; `decibelAmount` is a size (gate range, makeup) and reads without a sign.
    /// `delayTime` is milliseconds plus the distance sound travels in that time.
    case decibels, decibelAmount, hertz, milliseconds, delayTime, ratio, pan, plain
}

public struct ParamSpec: Sendable, Identifiable, Equatable {
    public let address: String
    public let label: String
    public let scale: ParamScale
    public let unit: ParamUnit
    /// What a double-tap restores at once, in real units; nil means double-tap does nothing. No reset asks
    /// first: the convenience outweighs an accidental double-tap on a 48 pt row.
    public let resetValue: Double?
    /// A choice's options in words, for the open list; nil when the desk's own names say enough.
    public let optionNames: [String]?

    public init(
        _ address: String, _ label: String, _ scale: ParamScale, _ unit: ParamUnit, reset: Double? = nil,
        optionNames: [String]? = nil
    ) {
        self.address = address
        self.label = label
        self.scale = scale
        self.unit = unit
        self.resetValue = reset
        self.optionNames = optionNames
    }

    public var id: String { address }

    /// Where the haptic "unity" tick fires: 0 dB on controls that reset to 0 dB.
    public var unityNormalized: Float? {
        guard unit == .decibels, resetValue == 0 else { return nil }
        return scale.normalized(forValue: 0)
    }
}

public struct GateSpecs: Sendable {
    public let on, mode, threshold, range, attack, hold, release: ParamSpec
    public var all: [ParamSpec] { [on, mode, threshold, range, attack, hold, release] }
}

public struct DynamicsSpecs: Sendable {
    public let on, mode, threshold, ratio, knee, attack, hold, release, makeup, detector, envelope, auto: ParamSpec
    public var all: [ParamSpec] {
        [on, mode, threshold, ratio, knee, attack, hold, release, makeup, detector, envelope, auto]
    }
    /// What the desk ignores while Auto time is on (the user, on the console, 2026-10-15).
    public var autoTimed: [ParamSpec] { [attack, release] }
}

/// What a gate or comp listens to: its key source and the filter on that signal.
public struct KeySpecs: Sendable {
    /// nil where the desk has no key source: a matrix's or main's comp (doc p.32-37). A choice needs the strips'
    /// names, so `Catalog.keySource` builds it.
    public let sourceAddress: String?
    public let filterOn, filterType, filterFrequency: ParamSpec
    public var addresses: [String] {
        [sourceAddress].compactMap { $0 } + [filterOn, filterType, filterFrequency].map(\.address)
    }
}

public struct DelaySpecs: Sendable, Equatable {
    public let on, time: ParamSpec
    public var all: [ParamSpec] { [on, time] }
}

public struct InsertSpecs: Sendable, Equatable {
    public let on, position, slot: ParamSpec
    public var all: [ParamSpec] { [on, position, slot] }
}

public struct LowCutSpecs: Sendable {
    public let on, frequency, slope: ParamSpec
    public var all: [ParamSpec] { [on, frequency, slope] }
}

public struct EQBandSpecs: Sendable {
    public let type, frequency, gain, q: ParamSpec
    public var all: [ParamSpec] { [type, frequency, gain, q] }
}

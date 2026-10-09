public enum ParamUnit: Sendable {
    /// `decibels` is a signed level or gain; `decibelAmount` is a size (gate range, makeup) and reads without a sign.
    /// `delayTime` is milliseconds plus the distance sound travels in that time.
    case decibels, decibelAmount, hertz, milliseconds, delayTime, percent, ratio, pan, plain
}

public struct ParamSpec: Sendable, Identifiable, Equatable {
    public let address: String
    public let label: String
    public let scale: ParamScale
    public let unit: ParamUnit
    /// What a double-tap restores, in real units; nil means double-tap does nothing.
    public let resetValue: Double?
    /// Asked with the system alert before a double-tap resets; nil resets at once.
    public let resetPrompt: String?
    /// A choice's options in words, for the open list; nil when the desk's own names say enough.
    public let optionNames: [String]?

    public init(
        _ address: String, _ label: String, _ scale: ParamScale, _ unit: ParamUnit, reset: Double? = nil,
        resetPrompt: String? = nil, optionNames: [String]? = nil
    ) {
        self.address = address
        self.label = label
        self.scale = scale
        self.unit = unit
        self.resetValue = reset
        self.resetPrompt = resetPrompt
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
    public let on, mode, threshold, ratio, knee, attack, hold, release, makeup, detector, envelope: ParamSpec
    public var all: [ParamSpec] {
        [on, mode, threshold, ratio, knee, attack, hold, release, makeup, detector, envelope]
    }
}

public struct DelaySpecs: Sendable, Equatable {
    public let on, time: ParamSpec
    public var all: [ParamSpec] { [on, time] }
}

public struct LowCutSpecs: Sendable {
    public let on, frequency, slope: ParamSpec
    public var all: [ParamSpec] { [on, frequency, slope] }
}

public struct EQBandSpecs: Sendable {
    public let type, frequency, gain, q: ParamSpec
    public var all: [ParamSpec] { [type, frequency, gain, q] }
}

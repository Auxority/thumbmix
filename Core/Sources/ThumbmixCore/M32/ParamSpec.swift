public enum ParamUnit: Sendable {
    /// `decibels` is a signed level or gain; `decibelAmount` is a size (gate range, makeup) and reads without a sign.
    case decibels, decibelAmount, hertz, milliseconds, percent, ratio, pan, plain
}

public struct ParamSpec: Sendable, Identifiable, Equatable {
    public let address: String
    public let label: String
    public let scale: ParamScale
    public let unit: ParamUnit
    /// What a double-tap restores, in real units; nil means double-tap does nothing.
    public let resetValue: Double?

    public init(
        _ address: String, _ label: String, _ scale: ParamScale, _ unit: ParamUnit, reset: Double? = nil
    ) {
        self.address = address
        self.label = label
        self.scale = scale
        self.unit = unit
        self.resetValue = reset
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
    public let on, mode, threshold, ratio, knee, attack, hold, release, makeup: ParamSpec
    public var all: [ParamSpec] { [on, mode, threshold, ratio, knee, attack, hold, release, makeup] }
}

public struct EQBandSpecs: Sendable {
    public let type, frequency, gain, q: ParamSpec
    public var all: [ParamSpec] { [type, frequency, gain, q] }
}

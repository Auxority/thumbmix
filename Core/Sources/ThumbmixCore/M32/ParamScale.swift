import Foundation

/// How a parameter's 0...1 position maps to real units, and how it travels on the wire.
public enum ParamScale: Equatable, Sendable {
    case fader
    case sendLevel
    case linear(min: Double, max: Double, step: Double)
    case log(min: Double, max: Double, steps: Int)
    case choice([String])
    case toggle

    public var steps: Int {
        switch self {
        case .fader: 1024
        case .sendLevel: 161
        case .linear(let low, let high, let step): Int(((high - low) / step).rounded()) + 1
        case .log(_, _, let steps): steps
        case .choice(let options): options.count
        case .toggle: 2
        }
    }

    /// The console snaps every value to its grid, so the UI does too and never shows in-between values.
    public func snap(_ normalized: Float) -> Float {
        let intervals = Float(steps - 1)
        return (Swift.min(Swift.max(normalized, 0), 1) * intervals).rounded() / intervals
    }

    /// dB, Hz, ms, pan units, or the option index for choices and toggles.
    public func value(fromNormalized normalized: Float) -> Double {
        let position = Double(Swift.min(Swift.max(normalized, 0), 1))
        switch self {
        case .fader, .sendLevel: return FaderLaw.decibels(fromWire: position)
        case .linear(let low, let high, _): return low + position * (high - low)
        case .log(let low, let high, _): return low * pow(high / low, position)
        case .choice, .toggle: return (position * Double(steps - 1)).rounded()
        }
    }

    public func normalized(forValue value: Double) -> Float {
        let position: Double
        switch self {
        case .fader, .sendLevel: position = FaderLaw.wire(fromDecibels: value)
        case .linear(let low, let high, _): position = (value - low) / (high - low)
        case .log(let low, let high, _):
            position = Foundation.log(value / low) / Foundation.log(high / low)
        case .choice, .toggle: position = value / Double(steps - 1)
        }
        return snap(Float(position))
    }

    public func argument(fromNormalized normalized: Float) -> OSCArgument {
        let snapped = snap(normalized)
        switch self {
        case .choice, .toggle: return .int(Int32((snapped * Float(steps - 1)).rounded()))
        default: return .float(snapped)
        }
    }

    /// nil when the console sent a type this parameter doesn't use.
    public func normalized(from argument: OSCArgument) -> Float? {
        switch (self, argument) {
        case (.choice, let .int(index)), (.toggle, let .int(index)): Float(index) / Float(steps - 1)
        case (.choice, _), (.toggle, _): nil
        case (_, let .float(value)): value
        default: nil
        }
    }
}

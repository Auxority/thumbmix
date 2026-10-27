import Foundation

/// What Reset gate, Reset comp and Reset input write, in real units. PROVISIONAL until m32-probe section 20 reads
/// the desk's own reset: the doc gives none. Thresholds sit at the harmless end: with the strip as its own key, a
/// wrong guess can't change the sound. A gate keyed from another strip stays keyed, so a key that falls silent closes
/// it. A double-tap restores the same value where a row has one (`ResetTests`).
extension Catalog {
    /// The shape only: On and the key stay as set, like Reset bands leaves EQ on and the low cut alone.
    public static func gateDefaults(_ strip: StripID) -> [(spec: ParamSpec, value: Double)] {
        guard strip.hasGate else { return [] }
        let gate = gate(strip)
        return [
            (gate.mode, Double(gateModes.firstIndex(of: "GATE") ?? 0)), (gate.threshold, -80), (gate.range, 60),
            (gate.attack, 0), (gate.hold, 50), (gate.release, 200),
        ]
    }

    /// The shape only: On, the key and Comp position stay as set.
    public static func dynamicsDefaults(_ strip: StripID) -> [(spec: ParamSpec, value: Double)] {
        guard strip.hasDynamics else { return [] }
        let dynamics = dynamics(strip)
        let mode = Double(dynamicsModes.firstIndex(of: "COMP") ?? 0)
        let ratio = Double(ratios.firstIndex(of: "3.0") ?? 0)
        let detector = Double(dynamicsDetectors.firstIndex(of: "PEAK") ?? 0)
        let envelope = Double(dynamicsEnvelopes.firstIndex(of: "LOG") ?? 0)
        return [
            (dynamics.mode, mode), (dynamics.threshold, 0), (dynamics.ratio, ratio), (dynamics.knee, 0),
            (dynamics.attack, 10), (dynamics.hold, 10), (dynamics.release, 150), (dynamics.makeup, 0),
            (dynamics.mix, 100), (dynamics.detector, detector), (dynamics.envelope, envelope), (dynamics.auto, 0),
        ]
    }

    /// Gain, trim, polarity and delay, as far as the strip has them. Never 48V: phantom power asks on its own, mic by
    /// mic. `headamp` is the preamp the desk says feeds the strip.
    public static func inputDefaults(_ strip: StripID, headamp: Int?) -> [(spec: ParamSpec, value: Double)] {
        let gain = headamp.map { [(spec: headampGain($0), value: 0.0)] } ?? []
        let polarity = invert(strip).map { [(spec: $0, value: 0.0)] } ?? []
        let delay = delay(strip).map { [(spec: $0.on, value: 0.0), (spec: $0.time, value: 0.3)] } ?? []
        return gain + [(spec: trim(strip), value: 0)] + polarity + delay
    }

    /// `defaults` as the desk's arguments, each snapped to the nearest step its scale has.
    public static func deskArguments(_ defaults: [(spec: ParamSpec, value: Double)]) -> [(
        address: String, argument: OSCArgument
    )] {
        defaults.map { spec, value in
            (spec.address, spec.scale.argument(fromNormalized: spec.scale.normalized(forValue: value)))
        }
    }
}

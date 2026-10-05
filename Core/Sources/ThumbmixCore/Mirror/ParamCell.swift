import Observation

/// One console value. Views observe only the cells they draw, so one fader move redraws one row.
@MainActor @Observable
public final class ParamCell {
    public internal(set) var argument: OSCArgument?
}

@MainActor @Observable
public final class MeterCell {
    /// Linear amplitude: 1.0 = 0 dBFS.
    public internal(set) var level: Float = 0
    /// Linear gain factors: 1.0 = no reduction.
    public internal(set) var gateGain: Float = 1
    public internal(set) var dynamicsGain: Float = 1
}

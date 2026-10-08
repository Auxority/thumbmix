/// How a held ±1 dB button repeats (mock A, picked over a growing step for its finer control). The step stays
/// 1 dB; only the pace rises, to about 20 dB per second, so a long hold still crosses the fader's range quickly.
public enum NudgeRepeat {
    /// A tap moves once; holding this long starts the repeats.
    public static let firstRepeat: Duration = .milliseconds(400)

    /// The wait before the next step, by how long the button has been held.
    public static func interval(afterHolding held: Duration) -> Duration {
        held < .milliseconds(1500) ? .milliseconds(150) : .milliseconds(50)
    }
}

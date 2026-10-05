import Foundation
import ThumbmixCore

/// Synthetic meters for the fake console; the desk state itself is `DemoState` in ThumbmixCore.
public enum FakeState {
    /// The RTA bank has its own packing (Int16 dB values); every other bank is floats.
    public static func meterBlob(bank: String, time: Double) -> Data {
        bank == RTA.bank
            ? MeterBlob.encodeRTA(spectrum(time: time)) : MeterBlob.encode(meterValues(bank: bank, time: time))
    }

    /// A falling pink-ish spectrum with a slowly sweeping bump, so the glow visibly moves in the simulator.
    public static func spectrum(time: Double) -> [Float] {
        (0..<RTA.bandCount).map { band in
            let position = Double(band) / Double(RTA.bandCount - 1)
            let bump = 14 * exp(-pow((position - 0.3 - 0.15 * sin(time * 0.7)) * 6, 2))
            let flicker = 3 * sin(time * 9 + Double(band))
            return Float(max(-24 - 40 * position + bump + flicker, -100))
        }
    }

    /// Slowly moving levels; gain-reduction slots hover below 1.0 (1.0 = no reduction).
    public static func meterValues(bank: String, time: Double) -> [Float] {
        let counts = ["/meters/0": 70, "/meters/1": 96, "/meters/2": 49, "/meters/5": 27]
        let reductionStart = ["/meters/1": 32, "/meters/2": 25]
        let count = counts[bank] ?? 4
        return (0..<count).map { index in
            let wave = Float(abs(sin(time * 1.5 + Double(index) * 0.7)))
            if let start = reductionStart[bank], index >= start { return 1 - 0.4 * wave }
            return 0.02 + 0.3 * wave
        }
    }
}

import Foundation
import ThumbmixCore

/// Synthetic meters for the fake console; the desk state itself is `DemoState` in ThumbmixCore.
enum FakeState {
    /// The RTA bank has its own packing (Int16 dB values); every other bank is floats.
    /// `afterEQ` adds the analysed channel's EQ (in dB, by frequency) to the RTA spectrum, like the desk's "after EQ".
    static func meterBlob(bank: String, time: Double, afterEQ: (Double) -> Double = { _ in 0 }) -> Data {
        bank == RTA.bank
            ? MeterBlob.encodeRTA(spectrum(time: time, afterEQ: afterEQ))
            : MeterBlob.encode(meterValues(bank: bank, time: time))
    }

    /// With the RTA "after EQ" on a strip, the curve the app draws for that strip's EQ and low cut. Whether the
    /// desk's "after EQ" includes the low cut is open (m32-probe section 6); the demo assumes it does.
    static func rtaAfterEQ(in state: [String: OSCArgument]) -> (Double) -> Double {
        guard state[RTA.position] == .int(RTA.afterEQ), case .int(let source)? = state[RTA.source],
            let strip = StripKind.allCases.flatMap(StripID.all).first(where: { $0.rtaSource == source })
        else { return { _ in 0 } }
        let bands = EQReading.bands(strip) { state[$0] }
        let lowCut = EQReading.lowCut(strip) { state[$0] }
        return { hertz in EQReading.decibels(at: hertz, bands: bands, lowCut: lowCut) }
    }

    /// A falling pink-ish spectrum with a slowly sweeping bump, so the glow visibly moves in the simulator.
    static func spectrum(time: Double, afterEQ: (Double) -> Double = { _ in 0 }) -> [Float] {
        (0..<RTA.bandCount).map { band in
            let position = Double(band) / Double(RTA.bandCount - 1)
            let bump = 14 * exp(-pow((position - 0.3 - 0.15 * sin(time * 0.7)) * 6, 2))
            let flicker = 3 * sin(time * 9 + Double(band))
            let eq = afterEQ(RTA.bandFrequency(band))
            return Float(max(-24 - 40 * position + bump + flicker + eq, -100))
        }
    }

    /// Slowly moving levels; gain-reduction slots hover below 1.0 (1.0 = no reduction).
    static func meterValues(bank: String, time: Double) -> [Float] {
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

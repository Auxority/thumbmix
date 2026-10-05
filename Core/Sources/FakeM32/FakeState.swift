import Foundation

/// Synthetic meters for the fake console; the desk state itself is `DemoState` in ThumbmixCore.
public enum FakeState {
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

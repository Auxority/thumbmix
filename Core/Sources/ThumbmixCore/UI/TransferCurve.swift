import Foundation

/// Static output level (dB) for an input level (dB): what the gate and compressor graphs draw.
/// Attack, hold and release shape how fast the desk follows this curve, not the curve itself.
public enum TransferCurve {
    /// In `Catalog.gateModes` order. The doc lists the modes without describing them; these shapes
    /// (EXPn = 1:n expander, GATE = cut, DUCK = cut above the threshold) were confirmed by the user.
    public enum GateMode: Int, Sendable {
        case exp2, exp3, exp4, gate, duck
    }

    public static func gateOutput(_ input: Double, mode: GateMode, threshold: Double, range: Double) -> Double {
        let floor = input - range
        switch mode {
        case .gate: return input < threshold ? floor : input
        case .duck: return input > threshold ? floor : input
        case .exp2, .exp3, .exp4:
            guard input < threshold else { return input }
            let ratio = Double(mode.rawValue + 2)
            return max(threshold + (input - threshold) * ratio, floor)
        }
    }

    /// `knee` is the desk's 0-5 setting. The doc gives it no unit, so it is drawn as 2 dB of soft-knee
    /// width per step: an approximation for seeing the shape, like `EQResponse`.
    public static func dynamicsOutput(
        _ input: Double, isExpander: Bool, threshold: Double, ratio: Double, knee: Double, makeup: Double
    ) -> Double {
        let curve =
            isExpander
            ? expanded(input, threshold: threshold, ratio: ratio)
            : compressed(input, threshold: threshold, ratio: ratio, kneeWidth: knee * 2)
        return curve + makeup
    }

    private static func expanded(_ input: Double, threshold: Double, ratio: Double) -> Double {
        input < threshold ? threshold + (input - threshold) * ratio : input
    }

    /// The usual quadratic soft knee centred on the threshold (Giannoulis, Massberg & Reiss, JAES 2012).
    private static func compressed(_ input: Double, threshold: Double, ratio: Double, kneeWidth: Double) -> Double {
        let overshoot = input - threshold
        if 2 * overshoot < -kneeWidth { return input }
        if 2 * abs(overshoot) <= kneeWidth, kneeWidth > 0 {
            let bend = overshoot + kneeWidth / 2
            return input + (1 / ratio - 1) * bend * bend / (2 * kneeWidth)
        }
        return threshold + overshoot / ratio
    }
}

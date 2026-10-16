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

    /// `knee` is the desk's 0-5 setting. The doc gives it no unit, so it is drawn as `kneeDecibelsPerStep` of
    /// soft-knee width per step: an approximation for seeing the shape, like `EQResponse`. `mix` is the desk's
    /// 0-100 %: what you hear is that share of the processed signal summed with the rest of the dry one.
    public static func dynamicsOutput(
        _ input: Double, isExpander: Bool, threshold: Double, ratio: Double, knee: Double, makeup: Double,
        mix: Double
    ) -> Double {
        let curve =
            isExpander
            ? expanded(input, threshold: threshold, ratio: ratio)
            : compressed(input, threshold: threshold, ratio: ratio, kneeWidth: knee * kneeDecibelsPerStep)
        return blended(dry: input, wet: curve + makeup, mix: mix)
    }

    /// Makeup gain lifts the processed signal only, before the blend: an assumption until the desk answers (TODO.md,
    /// m32-probe "Comp mix"). The ends return exactly, so 100 % draws the plain compressor curve.
    private static func blended(dry: Double, wet: Double, mix: Double) -> Double {
        if mix >= 100 { return wet }
        if mix <= 0 { return dry }
        let share = mix / 100
        return 20 * log10(share * pow(10, wet / 20) + (1 - share) * pow(10, dry / 20))
    }

    /// Knee 5 spans 30 dB, the widest common soft knee (Pro Tools' Dynamics III): 2 dB per step bent the curve
    /// under 1 dB, invisible on the graph. Replace with the desk's width once measured (TODO.md, "On the real M32").
    static let kneeDecibelsPerStep = 6.0

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

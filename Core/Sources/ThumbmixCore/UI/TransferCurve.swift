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

    /// A stretch of input levels where the curve either is the straight 1:1 line or leaves it.
    public struct ForkRun: Equatable, Sendable {
        public let inputs: ClosedRange<Double>
        public let splits: Bool
    }

    /// Splits `floor...0` dB into runs where `output` stays on or leaves the straight line, so the graph draws a
    /// shared stretch once and forks only where Gate or Comp changes the level (F1, 2026-10-17).
    public static func forkRuns(from floor: Double, steps: Int = 160, output: (Double) -> Double) -> [ForkRun] {
        let inputs = (0...steps).map { floor * (1 - Double($0) / Double(steps)) }
        let leaves = inputs.map { abs(output($0) - $0) > 0.01 }
        var runs: [ForkRun] = []
        for step in 0..<steps {
            let splits = leaves[step] || leaves[step + 1]
            if let last = runs.last, last.splits == splits {
                runs[runs.count - 1] = ForkRun(inputs: last.inputs.lowerBound...inputs[step + 1], splits: splits)
            } else {
                runs.append(ForkRun(inputs: inputs[step]...inputs[step + 1], splits: splits))
            }
        }
        return runs
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

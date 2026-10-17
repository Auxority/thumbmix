import SwiftUI
import ThumbmixCore

/// Output level against input level, both -80...0 dB, with the threshold and a dot riding what you hear at the
/// channel's current input level; gain reduction sits over the bottom edge. One card instead of a separate meter
/// keeps the threshold row on the first screen of a 375 pt phone.
/// Where the curve leaves the straight 1:1 line it forks (F1, 2026-10-17): what you hear is solid white, the
/// other state grey and dashed, so switching Gate or Comp swaps the two and nothing else moves.
struct TransferGraph: View {
    static let floor = -80.0

    struct Curve {
        let output: (Double) -> Double
        let threshold: Double
        let isOn: Bool

        /// Off, the signal passes untouched: out = in.
        var heard: (Double) -> Double { isOn ? output : { $0 } }
    }

    /// nil until the desk sent every value the curve needs: the card keeps its place, so nothing below it moves.
    let curve: Curve?
    let meter: MeterCell
    let reduction: KeyPath<MeterCell, Float>
    let identifier: String
    let label: LocalizedStringKey
    /// The other side of a pair whose sides can differ, drawn faint under this side's curve.
    var ghostOutput: ((Double) -> Double)?

    var body: some View {
        ZStack {
            Canvas { context, size in
                guard let curve else { return drawUnity(in: context, size: size) }
                drawThreshold(curve.threshold, in: context, size: size)
                if let ghostOutput {
                    context.stroke(path(ghostOutput, in: size), with: .color(.white.opacity(0.3)), lineWidth: 2)
                }
                drawFork(curve, in: context, size: size)
            }
            if let curve { LevelDot(meter: meter, output: curve.heard) }
        }
        .frame(height: Theme.graphHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
        .accessibilityValue(curve?.isOn == false ? Text("Off") : Text(verbatim: ""))
        // Over the plot's bottom edge, where the curve only runs at the quietest levels (layout A, 2026-10-17).
        .overlay(alignment: .bottom) {
            Reduction(meter: meter, reduction: reduction).padding(.horizontal, 12).padding(.bottom, 10)
        }
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func drawFork(_ curve: Curve, in context: GraphicsContext, size: CGSize) {
        let unheard = curve.isOn ? { $0 } : curve.output
        for run in TransferCurve.forkRuns(from: Self.floor, output: curve.output) {
            if run.splits {
                context.stroke(
                    path(unheard, over: run.inputs, in: size), with: .color(Theme.secondaryText),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }
            context.stroke(path(curve.heard, over: run.inputs, in: size), with: .color(.white), lineWidth: 2)
        }
    }

    private func path(_ output: (Double) -> Double, over inputs: ClosedRange<Double> = floor...0, in size: CGSize)
        -> Path
    {
        let steps = max(Int((inputs.upperBound - inputs.lowerBound) * 2), 1)
        var path = Path()
        for step in 0...steps {
            let input = inputs.lowerBound + (inputs.upperBound - inputs.lowerBound) * Double(step) / Double(steps)
            let point = Self.point(input: input, output: output(input), in: size)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    /// Only the 1:1 line until the curve's values are read, so On never jumps (2026-10-15).
    private func drawUnity(in context: GraphicsContext, size: CGSize) {
        context.stroke(path({ $0 }, in: size), with: .color(Theme.raised), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }

    private func drawThreshold(_ threshold: Double, in context: GraphicsContext, size: CGSize) {
        var thresholdLine = Path()
        let x = Self.point(input: threshold, output: 0, in: size).x
        thresholdLine.move(to: CGPoint(x: x, y: 0))
        thresholdLine.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(thresholdLine, with: .color(.yellow.opacity(0.6)), lineWidth: 1)
    }

    /// Values outside the axes (makeup above 0 dB, cuts below the floor) pin to the edge.
    static func point(input: Double, output: Double, in size: CGSize) -> CGPoint {
        let fraction = { (decibels: Double) in min(max((decibels - floor) / -floor, 0), 1) }
        return CGPoint(x: fraction(input) * size.width, y: (1 - fraction(output)) * size.height)
    }
}

/// Separate view so the 20 Hz meter updates redraw only the bar, not the curve.
private struct Reduction: View {
    let meter: MeterCell
    let reduction: KeyPath<MeterCell, Float>

    var body: some View {
        ReductionBar(gain: meter[keyPath: reduction])
    }
}

/// Separate view so the 20 Hz meter updates redraw only the dot, not the curve.
private struct LevelDot: View {
    let meter: MeterCell
    let output: (Double) -> Double

    var body: some View {
        let input = max(MeterScale.decibels(meter.level), TransferGraph.floor)
        GeometryReader { geometry in
            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)
                .position(TransferGraph.point(input: input, output: output(input), in: geometry.size))
        }
    }
}

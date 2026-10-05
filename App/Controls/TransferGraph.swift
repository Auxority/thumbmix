import SwiftUI
import ThumbmixCore

/// Output level against input level, both -80...0 dB, with the 1:1 line for reference, the threshold,
/// and a dot riding the curve at the channel's current input level; gain reduction sits underneath.
/// One card instead of a separate meter keeps the threshold row on the first screen of a 375 pt phone.
struct TransferGraph: View {
    static let floor = -80.0

    let output: (Double) -> Double
    let threshold: Double
    let meter: MeterCell
    let reduction: KeyPath<MeterCell, Float>
    let identifier: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Canvas { context, size in
                    drawReference(in: context, size: size)
                    context.stroke(curve(in: size), with: .color(.white), lineWidth: 2)
                }
                LevelDot(meter: meter, output: output)
            }
            .frame(height: 140)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(label)
            Reduction(meter: meter, reduction: reduction)
        }
        .padding(12)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 12))
    }

    private func curve(in size: CGSize) -> Path {
        var path = Path()
        for step in 0...160 {
            let input = Self.floor * (1 - Double(step) / 160)
            let point = Self.point(input: input, output: output(input), in: size)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private func drawReference(in context: GraphicsContext, size: CGSize) {
        var unity = Path()
        unity.move(to: Self.point(input: Self.floor, output: Self.floor, in: size))
        unity.addLine(to: Self.point(input: 0, output: 0, in: size))
        context.stroke(unity, with: .color(Theme.raised), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
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

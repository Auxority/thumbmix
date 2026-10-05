import SwiftUI
import ThumbmixCore

struct MeterBar: View {
    let level: Float
    var threshold: Double?
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.raised)
                Capsule()
                    .fill(Self.color(for: level))
                    .frame(width: geometry.size.width * MeterScale.fraction(linear: level))
                if let threshold {
                    Rectangle()
                        .fill(.white)
                        .frame(width: 2)
                        .offset(x: geometry.size.width * MeterScale.fraction(decibels: threshold) - 1)
                }
            }
        }
        .frame(height: height)
    }

    static func color(for level: Float) -> Color {
        switch MeterScale.decibels(level) {
        case ..<(-12): .green
        case ..<(-3): .yellow
        default: .red
        }
    }
}

/// Gain reduction, filling from the right, full scale 30 dB.
struct ReductionBar: View {
    let gain: Float

    var body: some View {
        let reduction = MeterScale.reductionDecibels(gain: gain)
        HStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    Capsule().fill(Theme.raised)
                    Capsule().fill(.orange).frame(width: geometry.size.width * min(reduction / 30, 1))
                }
            }
            .frame(height: 10)
            Text("GR \(ValueText.number(reduction, digits: 1)) dB")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

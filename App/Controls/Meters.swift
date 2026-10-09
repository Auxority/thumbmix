import SwiftUI
import ThumbmixCore

extension View {
    /// Shows `fraction` of a full-width fill by scaling it: a changing frame re-ran layout up the row for every
    /// meter, 20 times a second (Instruments, iPhone 11 Pro). Never 0: a zero scale can't be inverted.
    func meterFill(_ fraction: Double, from anchor: UnitPoint) -> some View {
        scaleEffect(x: max(fraction, 0.001), y: 1, anchor: anchor)
    }
}

/// Gain reduction, filling from the right, full scale 30 dB.
struct ReductionBar: View {
    let gain: Float

    var body: some View {
        let reduction = MeterScale.reductionDecibels(gain: gain)
        HStack(spacing: 8) {
            ZStack {
                Capsule().fill(Theme.raised)
                Capsule().fill(.orange).meterFill(min(reduction / 30, 1), from: .trailing)
            }
            .frame(height: 10)
            Text("GR \(ValueText.number(reduction, digits: 1)) dB")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

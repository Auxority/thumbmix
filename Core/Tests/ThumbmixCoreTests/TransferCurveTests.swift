import Testing

@testable import ThumbmixCore

struct TransferCurveTests {
    private func gate(_ input: Double, _ mode: TransferCurve.GateMode) -> Double {
        TransferCurve.gateOutput(input, mode: mode, threshold: -40, range: 30)
    }

    @Test func gateCutsByTheRangeBelowTheThreshold() {
        #expect(gate(-50, .gate) == -80)
        #expect(gate(-30, .gate) == -30)
    }

    @Test func expanderSteepensBelowTheThresholdDownToTheRange() {
        #expect(gate(-45, .exp2) == -50)
        #expect(gate(-45, .exp4) == -60)
        // Never more than the range below the input.
        #expect(gate(-60, .exp4) == -90)
        #expect(gate(-30, .exp3) == -30)
    }

    @Test func duckerCutsByTheRangeAboveTheThreshold() {
        #expect(gate(-30, .duck) == -60)
        #expect(gate(-50, .duck) == -50)
    }

    @Test func gateModesFollowTheCatalogOrder() {
        #expect(Catalog.gateModes.indices.map { TransferCurve.GateMode(rawValue: $0) } == [.exp2, .exp3, .exp4, .gate, .duck])
    }

    private func compressor(_ input: Double, knee: Double = 0, makeup: Double = 0, expander: Bool = false) -> Double {
        TransferCurve.dynamicsOutput(input, isExpander: expander, threshold: -20, ratio: 4, knee: knee, makeup: makeup)
    }

    @Test func hardKneeCompressorDividesTheOvershootByTheRatio() {
        #expect(compressor(-30) == -30)
        #expect(compressor(0) == -15)
    }

    @Test func makeupLiftsTheWholeCurve() {
        #expect(compressor(-30, makeup: 6) == -24)
        #expect(compressor(0, makeup: 6) == -9)
    }

    @Test func softKneeBendsAroundTheThresholdOnly() {
        // Softer than a hard knee at the threshold, identical well outside the knee.
        #expect(compressor(-20, knee: 5) < -20)
        #expect(compressor(-40, knee: 5) == -40)
        #expect(compressor(0, knee: 5) == -15)
    }

    @Test func expanderModeSteepensBelowTheThreshold() {
        #expect(compressor(-25, expander: true) == -40)
        #expect(compressor(-10, expander: true) == -10)
    }
}

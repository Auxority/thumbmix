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

    private func compressor(
        _ input: Double, knee: Double = 0, makeup: Double = 0, mix: Double = 100, expander: Bool = false
    ) -> Double {
        TransferCurve.dynamicsOutput(
            input, isExpander: expander, threshold: -20, ratio: 4, knee: knee, makeup: makeup, mix: mix)
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

    /// At 2 dB per step the widest knee bent a 4:1 curve under 1 dB: invisible on the 80 dB graph. At 6 dB per
    /// step (30 dB, Pro Tools' widest) it bends ~2.8 dB.
    @Test func widestKneeBendsVisibly() {
        #expect(compressor(-20, knee: 5) < -22.5)
        #expect(compressor(-36, knee: 5) == -36, "the knee starts 15 dB below the threshold")
    }

    @Test func demoKneeIsAWholeStep() {
        #expect(DemoState.values()["/ch/01/dyn/knee"] == .float(0.6), "knee 3 of 0-5")
    }

    @Test func expanderModeSteepensBelowTheThreshold() {
        #expect(compressor(-25, expander: true) == -40)
        #expect(compressor(-10, expander: true) == -10)
    }

    @Test func noMixLeavesTheSignalDry() {
        #expect(compressor(0, makeup: 6, mix: 0) == 0)
        #expect(compressor(-30, makeup: 6, mix: 0) == -30)
    }

    /// Parallel compression: the two signals add as amplitudes, Makeup on the compressed one only (assumed).
    @Test func halfMixSumsTheCompressedAndDrySignals() {
        // Below the threshold: half of −24 dB plus half of −30 dB.
        #expect(abs(compressor(-30, makeup: 6, mix: 50) - -26.49) < 0.01)
        // Above it: less squashed than the compressor alone, still under the dry signal.
        let blended = compressor(0, mix: 50)
        #expect(blended > -15 && blended < 0)
    }

    /// The graph draws a stretch once where the curve is the straight line, and forks it where they differ (F1).
    @Test func forkSplitsOnlyWhereTheCurveLeavesTheStraightLine() {
        let comp = TransferCurve.forkRuns(from: -80) { compressor($0) }
        #expect(comp == [.init(inputs: -80 ... -20, splits: false), .init(inputs: -20...0, splits: true)])
        let gate = TransferCurve.forkRuns(from: -80) { gate($0, .gate) }
        #expect(gate == [.init(inputs: -80 ... -40, splits: true), .init(inputs: -40...0, splits: false)])
        // Makeup lifts every level, so the two lines never meet.
        #expect(TransferCurve.forkRuns(from: -80) { compressor($0, makeup: 6) } == [.init(inputs: -80...0, splits: true)])
    }
}

import Testing
@testable import ThumbmixCore

struct ParamScaleTests {
    @Test(arguments: [(0.75, 0.0), (0.825, 3.0), (0.5, -10.0), (0.25, -30.0), (0.0625, -60.0), (1.0, 10.0)])
    func faderLawMatchesDocBreakpoints(wire: Double, decibels: Double) {
        #expect(abs(FaderLaw.decibels(fromWire: wire) - decibels) < 0.001)
        #expect(abs(FaderLaw.wire(fromDecibels: decibels) - wire) < 0.0001)
    }

    @Test func faderBottomIsMinusInfinity() {
        #expect(FaderLaw.decibels(fromWire: 0) == -.infinity)
        #expect(FaderLaw.wire(fromDecibels: -.infinity) == 0)
    }

    @Test func faderUnitySnapsToConsoleGrid() {
        // The console stores 0 dB as int(0.75 * 1023.5) / 1023 (doc p.131).
        #expect(ParamScale.fader.normalized(forValue: 0) == Float(767) / 1023)
    }

    @Test func sendLevelUses161Steps() {
        #expect(ParamScale.sendLevel.steps == 161)
        #expect(ParamScale.sendLevel.normalized(forValue: 0) == 0.75)
    }

    @Test func linearTrimCentreIsZeroDecibels() {
        let trim = ParamScale.linear(min: -18, max: 18, step: 0.25)
        #expect(trim.steps == 145)
        #expect(trim.normalized(forValue: 0) == 0.5)
        #expect(trim.value(fromNormalized: 1) == 18)
    }

    @Test func headampGainMapping() {
        let gain = ParamScale.linear(min: -12, max: 60, step: 0.5)
        #expect(gain.normalized(forValue: 24) == 0.5)
    }

    @Test func logFrequencyMatchesDoc() {
        let frequency = ParamScale.log(min: 20, max: 20_000, steps: 201)
        #expect(abs(frequency.value(fromNormalized: 0.5) - 632.46) < 0.1)
        #expect(abs(frequency.value(fromNormalized: 1) - 20_000) < 0.01)
    }

    @Test func logQRunsHighToLow() {
        let q = ParamScale.log(min: 10, max: 0.3, steps: 72)
        #expect(q.value(fromNormalized: 0) == 10)
        #expect(abs(q.value(fromNormalized: 1) - 0.3) < 0.0001)
    }

    @Test func choiceTravelsAsInt() {
        let ratio = ParamScale.choice(["1.1", "1.3", "1.5", "2.0", "2.5", "3.0", "4.0", "5.0", "7.0", "10", "20", "100"])
        #expect(ratio.argument(fromNormalized: Float(3) / 11) == .int(3))
        #expect(ratio.normalized(from: .int(3)) == Float(3) / 11)
        #expect(ratio.value(fromNormalized: Float(3) / 11) == 3)
    }

    @Test func toggleTravelsAsInt() {
        #expect(ParamScale.toggle.argument(fromNormalized: 1) == .int(1))
        #expect(ParamScale.toggle.normalized(from: .int(0)) == 0)
    }

    @Test func continuousTravelsAsSnappedFloat() {
        #expect(ParamScale.sendLevel.argument(fromNormalized: 0.7531) == .float(0.75))
    }

    @Test func wrongArgumentTypeIsNil() {
        #expect(ParamScale.fader.normalized(from: .string("x")) == nil)
        #expect(ParamScale.toggle.normalized(from: .float(1)) == nil)
    }

    @Test func snapClampsOutOfRange() {
        #expect(ParamScale.fader.snap(1.4) == 1)
        #expect(ParamScale.fader.snap(-0.2) == 0)
    }
}

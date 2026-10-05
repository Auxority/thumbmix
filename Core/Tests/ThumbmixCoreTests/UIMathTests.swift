import Testing
@testable import ThumbmixCore

struct UIMathTests {
    private let fader = Catalog.fader(StripID(.input, 1))

    @Test func dragAcrossFullWidthIsFullRange() {
        #expect(RelativeDrag.value(start: 0, translation: 200, width: 200, scale: .fader) == 1)
        #expect(RelativeDrag.value(start: 0.5, translation: -50, width: 200, scale: .toggle) == 0)
        #expect(RelativeDrag.value(start: 0.3, translation: 10, width: 0, scale: .fader) == 0.3)
    }

    @Test func crossingUnityBothWays() {
        #expect(RelativeDrag.crossed(0.75, from: 0.7, to: 0.8))
        #expect(RelativeDrag.crossed(0.75, from: 0.8, to: 0.75))
        #expect(!RelativeDrag.crossed(0.75, from: 0.75, to: 0.8))
        #expect(!RelativeDrag.crossed(0.75, from: 0.1, to: 0.2))
    }

    @Test func nudgeMovesOneDecibel() {
        let up = RelativeDrag.nudged(ParamScale.fader.normalized(forValue: 0), byDecibels: 1, scale: .fader)
        #expect(abs(ParamScale.fader.value(fromNormalized: up) - 1) < 0.05)
        #expect(RelativeDrag.nudged(0, byDecibels: 1, scale: .fader) > 0)
    }

    @Test func decibelText() {
        #expect(ValueText.format(ParamScale.fader.normalized(forValue: 0), fader) == "0.0 dB")
        #expect(ValueText.format(0, fader) == "−∞ dB")
        #expect(ValueText.format(0.825, fader) == "+3.0 dB")
        #expect(ValueText.format(0.5, fader) == "−10.0 dB")
        #expect(ValueText.format(nil, fader) == "—")
    }

    @Test func otherUnits() {
        let band = Catalog.eqBand(StripID(.input, 1), 1)
        #expect(ValueText.format(0.5, band.frequency) == "632 Hz")
        #expect(ValueText.format(1, band.frequency) == "20.00 kHz")
        let pan = Catalog.pan(StripID(.input, 1))!
        #expect(ValueText.format(0.5, pan) == "C")
        #expect(ValueText.format(0.75, pan) == "R50")
        #expect(ValueText.format(0.25, pan) == "L50")
        let dynamics = Catalog.dynamics(StripID(.input, 1))
        #expect(ValueText.format(Float(3) / 11, dynamics.ratio) == "2.0:1")
        #expect(ValueText.format(1, dynamics.on) == "On")
        #expect(ValueText.format(0, dynamics.hold) == "0.02 ms")
        #expect(ValueText.format(1, dynamics.release) == "4000 ms")
    }

    @Test func groups() {
        #expect(StripGroup.inputs.strips.count == 32)
        #expect(StripGroup.main.strips == [StripID(.mainStereo), StripID(.mainMono)])
        #expect(StripGroup.allCases.map(\.rawValue) == ["Inputs", "Aux", "FX", "Buses", "DCA", "Main"])
    }

    @Test func meterScale() {
        #expect(MeterScale.fraction(linear: 1) == 1)
        #expect(MeterScale.fraction(linear: 0) == 0)
        #expect(abs(MeterScale.fraction(linear: 0.001) - 0) < 0.0001)
        #expect(abs(MeterScale.fraction(decibels: -30) - 0.5) < 0.0001)
        #expect(MeterScale.reductionDecibels(gain: 1) == 0)
        #expect(abs(MeterScale.reductionDecibels(gain: 0.5) - 6.02) < 0.01)
    }

    @Test func tabsPerKind() {
        #expect(ChannelTab.tabs(for: .input) == [.input, .gate, .eq, .comp, .sends])
        #expect(ChannelTab.tabs(for: .bus) == [.eq, .comp, .fedBy])
        #expect(ChannelTab.tabs(for: .mainMono) == [.eq, .comp])
        #expect(ChannelTab.tabs(for: .dca) == [.members])
        #expect(ChannelTab.tabs(for: .fxReturn).isEmpty)
    }
}

import Foundation
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
        #expect(ValueText.format(ParamScale.fader.normalized(forValue: 0), fader, locale: .testEnglish) == "0.0 dB")
        #expect(ValueText.format(0, fader, locale: .testEnglish) == "−∞ dB")
        #expect(ValueText.format(0.825, fader, locale: .testEnglish) == "+3.0 dB")
        #expect(ValueText.format(0.5, fader, locale: .testEnglish) == "−10.0 dB")
        #expect(ValueText.format(nil, fader, locale: .testEnglish) == "—")
    }

    @Test func otherUnits() {
        let band = Catalog.eqBand(StripID(.input, 1), 1)
        #expect(ValueText.format(0.5, band.frequency, locale: .testEnglish) == "632 Hz")
        #expect(ValueText.format(1, band.frequency, locale: .testEnglish) == "20.00 kHz")
        let pan = Catalog.pan(StripID(.input, 1))!
        #expect(ValueText.format(0.5, pan, locale: .testEnglish) == "C")
        #expect(ValueText.format(0.75, pan, locale: .testEnglish) == "R50")
        #expect(ValueText.format(0.25, pan, locale: .testEnglish) == "L50")
        let dynamics = Catalog.dynamics(StripID(.input, 1))
        #expect(ValueText.format(Float(3) / 11, dynamics.ratio, locale: .testEnglish) == "2.0:1")
        #expect(ValueText.format(1, dynamics.on, locale: .testEnglish) == "On")
        #expect(ValueText.format(0, dynamics.hold, locale: .testEnglish) == "0.02 ms")
        #expect(ValueText.format(1, dynamics.release, locale: .testEnglish) == "4000 ms")
    }

    @Test func formatsForTheUsersLocale() {
        let dutch = Locale(identifier: "nl_NL")
        let band = Catalog.eqBand(StripID(.input, 1), 1)
        #expect(ValueText.format(0.5, fader, locale: dutch) == "−10,0 dB")
        #expect(ValueText.format(1, band.frequency, locale: dutch) == "20,00 kHz")
        #expect(ValueText.format(1, Catalog.dynamics(StripID(.input, 1)).release, locale: dutch) == "4000 ms")
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

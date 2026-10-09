import Testing

@testable import ThumbmixCore

struct CatalogTests {
    @Test func prefixes() {
        #expect(StripID(.input, 1).prefix == "/ch/01")
        #expect(StripID(.auxIn, 8).prefix == "/auxin/08")
        #expect(StripID(.fxReturn, 2).prefix == "/fxrtn/02")
        #expect(StripID(.bus, 16).prefix == "/bus/16")
        #expect(StripID(.mainStereo).prefix == "/main/st")
        #expect(StripID(.mainMono).prefix == "/main/m")
        #expect(StripID(.dca, 3).prefix == "/dca/3")
    }

    @Test func dcaFaderAndOnHaveNoMixLevel() {
        #expect(StripID(.dca, 3).fader == "/dca/3/fader")
        #expect(StripID(.dca, 3).on == "/dca/3/on")
        #expect(StripID(.input, 1).fader == "/ch/01/mix/fader")
    }

    @Test func monoMainHasNoPan() {
        #expect(StripID(.mainMono).pan == nil)
        #expect(StripID(.mainStereo).pan == "/main/st/mix/pan")
    }

    @Test func sendAndHeadampAddresses() {
        #expect(Catalog.sendLevel(from: StripID(.input, 1), to: StripID(.bus, 16)).address == "/ch/01/mix/16/level")
        #expect(Catalog.sendOn(from: StripID(.fxReturn, 1), to: StripID(.bus, 2)).address == "/fxrtn/01/mix/02/on")
        #expect(Catalog.headampGain(32).address == "/headamp/032/gain")
        #expect(Catalog.headampPhantom(5).address == "/headamp/005/phantom")
        #expect(Catalog.headampIndex(forInput: 1) == "/-ha/00/index")
        #expect(Catalog.headampIndex(forInput: 32) == "/-ha/31/index")
    }

    @Test func eqBandCounts() {
        #expect(StripID(.input, 1).eqBandCount == 4)
        #expect(StripID(.bus, 1).eqBandCount == 6)
        #expect(StripID(.mainMono).eqBandCount == 6)
        #expect(StripID(.auxIn, 1).eqBandCount == 0)
        #expect(Catalog.eqBand(StripID(.bus, 2), 6).q.address == "/bus/02/eq/6/q")
    }

    @Test func mainEQHasExtraTypes() {
        guard case .choice(let main) = Catalog.eqBand(StripID(.mainStereo), 1).type.scale,
            case .choice(let bus) = Catalog.eqBand(StripID(.bus, 1), 1).type.scale
        else {
            Issue.record("EQ type must be a choice")
            return
        }
        #expect(main.count == 14)
        #expect(bus.count == 6)
    }

    /// The curve drawn for dynamics depends on it: a desk set to EXP must not be drawn as a compressor.
    @Test func dynamicsMirrorsCompOrExpMode() {
        let mode = Catalog.dynamics(StripID(.bus, 3)).mode
        #expect(mode.address == "/bus/03/dyn/mode")
        #expect(mode.scale == .choice(["COMP", "EXP"]))
        #expect(Catalog.syncAddresses().contains("/ch/01/dyn/mode"))
        #expect(DemoState.values()["/ch/01/dyn/mode"] == .int(0))
    }

    /// Separate 0/1 enums on every strip with dynamics (doc p.25, 33, 36, 38, 40).
    @Test func compressorHasDetectorAndEnvelope() {
        let dynamics = Catalog.dynamics(StripID(.mainMono))
        #expect(dynamics.detector.address == "/main/m/dyn/det")
        #expect(dynamics.detector.scale == .choice(["PEAK", "RMS"]))
        #expect(dynamics.envelope.address == "/main/m/dyn/env")
        #expect(dynamics.envelope.scale == .choice(["LIN", "LOG"]))
        #expect(Catalog.syncAddresses().contains("/ch/01/dyn/det"))
        #expect(Catalog.syncAddresses().contains("/mtx/06/dyn/env"))
        #expect(DemoState.values()["/ch/01/dyn/det"] == .int(0))
        #expect(DemoState.values()["/bus/01/dyn/env"] == .int(1))
    }

    /// A reset that can make the channel louder asks first; dropping makeup gain to 0 dB can't.
    @Test func makeupGainResetsAtOnceAndRatioAsks() {
        let dynamics = Catalog.dynamics(StripID(.input, 1))
        #expect(dynamics.makeup.label == "Makeup gain")
        #expect(dynamics.makeup.resetValue == 0)
        #expect(dynamics.makeup.resetPrompt == nil)
        #expect(dynamics.ratio.resetValue == Catalog.ratios.firstIndex(of: "3.0").map(Double.init))
        #expect(dynamics.ratio.resetPrompt == "Reset the ratio to 3:1?")
    }

    @Test func syncListIsCompleteAndUnique() {
        let addresses = Catalog.syncAddresses()
        // 32 inputs x 81 + 8 aux x 39 + 8 FX x 39 + 16 buses x 55 + 6 matrices x 41 + LR 54 + M 53 + 8 DCAs x 5
        // + 128 headamps x 2 + /-prefs/rta/source and /pos + 16 + 4 + 4 + 8 + 3 link pairs + 4 Link Preferences
        // (a bus or main has 12 matrix-send addresses)
        #expect(addresses.count == 4786)
        #expect(Set(addresses).count == addresses.count)
    }

    @Test func unityExistsForDecibelControlsWithZeroReset() {
        #expect(Catalog.fader(StripID(.input, 1)).unityNormalized == Float(767) / 1023)
        #expect(Catalog.eqBand(StripID(.input, 1), 1).gain.unityNormalized == 0.5)
        #expect(Catalog.headampGain(0).unityNormalized == Float(24) / 144, "preamp gain resets to 0 dB, so it ticks there")
        #expect(Catalog.trim(StripID(.input, 1)).unityNormalized == 0.5)
        #expect(Catalog.gate(StripID(.input, 1)).threshold.unityNormalized == nil, "no reset, no tick")
    }

    @Test func colors() {
        #expect(ConsoleColor(index: 3) == ConsoleColor(base: .yellow, inverted: false))
        #expect(ConsoleColor(index: 9) == ConsoleColor(base: .red, inverted: true))
        #expect(ConsoleColor(index: 99) == ConsoleColor(base: .off, inverted: false))
    }

    @Test func defaultNames() {
        #expect(StripID(.input, 7).defaultName == "Ch 7")
        #expect(StripID(.mainStereo).defaultName == "Main LR")
        #expect(StripID(.dca, 2).defaultName == "DCA 2")
    }
}

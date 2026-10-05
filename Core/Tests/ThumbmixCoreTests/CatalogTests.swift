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
        #expect(Catalog.sendLevel(from: StripID(.input, 1), toBus: 16).address == "/ch/01/mix/16/level")
        #expect(Catalog.sendOn(from: StripID(.fxReturn, 1), toBus: 2).address == "/fxrtn/01/mix/02/on")
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

    @Test func syncListIsCompleteAndUnique() {
        let addresses = Catalog.syncAddresses()
        // 32 inputs x 73 + 8 aux x 38 + 8 FX x 38 + 16 buses x 40 + LR 39 + M 38 + 8 DCAs x 4 + 128 headamps x 2
        #expect(addresses.count == 3949)
        #expect(Set(addresses).count == addresses.count)
    }

    @Test func unityExistsForDecibelControlsWithZeroReset() {
        #expect(Catalog.fader(StripID(.input, 1)).unityNormalized == Float(767) / 1023)
        #expect(Catalog.eqBand(StripID(.input, 1), 1).gain.unityNormalized == 0.5)
        #expect(Catalog.headampGain(0).unityNormalized == nil)
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

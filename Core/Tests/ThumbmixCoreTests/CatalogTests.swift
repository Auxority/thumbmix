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
        #expect(Catalog.headampIndex(StripID(.input, 1)) == "/-ha/00/index")
        #expect(Catalog.headampIndex(StripID(.input, 32)) == "/-ha/31/index")
        #expect(Catalog.headampIndex(StripID(.auxIn, 1)) == "/-ha/32/index", "aux 1-8 follow the 32 inputs (doc p.43)")
        #expect(Catalog.headampIndex(StripID(.auxIn, 8)) == "/-ha/39/index")
        #expect(Catalog.headampIndex(StripID(.fxReturn, 1)) == nil)
    }

    /// The demo's aux ins are the line-level jacks: no preamp, so their Input tab shows Trim only.
    @Test func theDemosAuxInsHaveNoPreamp() throws {
        let values = DemoState.values()
        #expect(values[try #require(Catalog.headampIndex(StripID(.auxIn, 1)))] == .int(-1))
        #expect(values[try #require(Catalog.headampIndex(StripID(.input, 1)))] == .int(32))
    }

    /// The desk keeps one pan per odd send, for the pair it feeds when linked (doc p.26).
    @Test func onlyOddSendsHaveAPan() {
        let vox = StripID(.input, 13)
        #expect(Catalog.sendPan(from: vox, to: StripID(.bus, 5))?.address == "/ch/13/mix/05/pan")
        #expect(Catalog.sendPan(from: vox, to: StripID(.bus, 6)) == nil)
        #expect(Catalog.sendPan(from: StripID(.bus, 1), to: StripID(.matrix, 3))?.address == "/bus/01/mix/03/pan")
        #expect(Catalog.sendPanFollow(from: vox, to: StripID(.bus, 5))?.address == "/ch/13/mix/05/panFollow")
        #expect(Catalog.sendPanFollow(from: vox, to: StripID(.bus, 6)) == nil)
        #expect(!Catalog.allAddresses().contains("/fxrtn/01/mix/01/pan"), "no Sends tab shows it: not worth the sync")
        #expect(Catalog.allAddresses().contains("/auxin/01/mix/01/pan"), "an aux in's Sends tab shows it")
        #expect(DemoState.values()["/ch/13/mix/05/panFollow"] == .int(0), "a toggle, not mid-travel")
        #expect(DemoState.values()["/ch/13/mix/05/pan"] == .float(0.5), "centre")
    }

    /// The tap point is the odd send's too (doc p.26); the chain also needs where the strip's comp sits.
    @Test func oddSendsHaveATapPoint() {
        let vox = StripID(.input, 13)
        #expect(Catalog.sendTap(from: vox, to: StripID(.bus, 1))?.address == "/ch/13/mix/01/type")
        #expect(Catalog.sendTap(from: vox, to: StripID(.bus, 2)) == nil)
        #expect(Catalog.dynamicsPosition(vox)?.address == "/ch/13/dyn/pos")
        #expect(Catalog.dynamicsPosition(StripID(.mainStereo))?.address == "/main/st/dyn/pos")
        #expect(Catalog.dynamicsPosition(StripID(.auxIn, 1)) == nil, "an aux in has no dynamics")
        #expect(DemoState.values()["/ch/13/mix/01/type"] == .int(3), "the demo's wedges are fed before the fader")
        #expect(DemoState.values()["/ch/13/dyn/pos"] == .int(1), "the demo's comps sit after the EQ")
    }

    @Test func eqBandCounts() {
        #expect(StripID(.input, 1).eqBandCount == 4)
        #expect(StripID(.bus, 1).eqBandCount == 6)
        #expect(StripID(.mainMono).eqBandCount == 6)
        #expect(StripID(.auxIn, 1).eqBandCount == 4, "doc p.28")
        #expect(StripID(.fxReturn, 1).eqBandCount == 0, "not shown yet")
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
        #expect(Catalog.allAddresses().contains("/ch/01/dyn/mode"))
        #expect(DemoState.values()["/ch/01/dyn/mode"] == .int(0))
    }

    /// Separate 0/1 enums on every strip with dynamics (doc p.25, 33, 36, 38, 40).
    @Test func compressorHasDetectorAndEnvelope() {
        let dynamics = Catalog.dynamics(StripID(.mainMono))
        #expect(dynamics.detector.address == "/main/m/dyn/det")
        #expect(dynamics.detector.scale == .choice(["PEAK", "RMS"]))
        #expect(dynamics.envelope.address == "/main/m/dyn/env")
        #expect(dynamics.envelope.scale == .choice(["LIN", "LOG"]))
        #expect(Catalog.allAddresses().contains("/ch/01/dyn/det"))
        #expect(Catalog.allAddresses().contains("/mtx/06/dyn/env"))
        #expect(DemoState.values()["/ch/01/dyn/det"] == .int(0))
        #expect(DemoState.values()["/bus/01/dyn/env"] == .int(1))
    }

    /// The open list says each choice in words, the desk's name under it; the closed row keeps the desk's name.
    @Test func dynamicsChoicesHaveWordsForTheList() {
        let dynamics = Catalog.dynamics(StripID(.input, 1))
        #expect(dynamics.mode.optionNames == ["Compressor", "Expander"])
        #expect(dynamics.detector.optionNames == ["Peak level", "Average level"])
        #expect(dynamics.envelope.optionNames == ["Linear", "Logarithmic"])
        #expect(
            Catalog.gate(StripID(.input, 1)).mode.optionNames == [
                "Expander 1:2", "Expander 1:3", "Expander 1:4", "Gate", "Ducker",
            ])
        #expect(Catalog.eqBand(StripID(.input, 1), 1).type.optionNames == nil, "EQ types keep the desk's names")
    }

    @Test func makeupGainAndRatioResetValues() {
        let dynamics = Catalog.dynamics(StripID(.input, 1))
        #expect(dynamics.makeup.label == "Makeup gain")
        #expect(dynamics.makeup.resetValue == 0)
        #expect(dynamics.ratio.resetValue == Catalog.ratios.firstIndex(of: "3.0").map(Double.init))
    }

    @Test func syncListIsUnique() {
        let addresses = Catalog.allAddresses()
        #expect(Set(addresses).count == addresses.count)
    }

    /// Whatever a tab shows is read: on connect (the overview) or when the tab opens. A value missing here would never
    /// be read, and its row would stay disabled. Checked per tab, not as a pinned total, so PRs don't conflict over it.
    @Test func everyTabsParametersAreRead() {
        let overview = Set(Catalog.overviewAddresses())
        for strip in StripKind.allCases.flatMap(StripID.all) {
            for tab in ChannelTab.tabs(for: strip.kind) {
                let read = overview.union(Catalog.tabAddresses(tab, strip, headamp: 32))
                for address in Self.shownAddresses(tab, strip) {
                    #expect(read.contains(address), "\(tab) of \(strip): \(address)")
                }
            }
        }
    }

    private static func shownAddresses(_ tab: ChannelTab, _ strip: StripID) -> [String] {
        switch tab {
        case .mix:
            [Catalog.fader(strip).address, Catalog.on(strip).address, strip.solo]
                + [Catalog.pan(strip)?.address, strip.mainLR].compactMap { $0 }
        case .input:
            [Catalog.trim(strip).address] + [Catalog.headampIndex(strip), Catalog.invert(strip)?.address].compactMap { $0 }
                + (Catalog.delay(strip)?.all.map(\.address) ?? [])
        case .gate: Catalog.gate(strip).all.map(\.address)
        case .eq:
            [Catalog.eqOn(strip).address] + (Catalog.lowCut(strip)?.all.map(\.address) ?? [])
                + (1...strip.eqBandCount).flatMap { Catalog.eqBand(strip, $0).all.map(\.address) }
        case .comp: Catalog.dynamics(strip).all.map(\.address)
        case .sends:
            (strip.kind.sendTarget.map(StripID.all) ?? []).flatMap {
                [Catalog.sendLevel(from: strip, to: $0).address, Catalog.sendOn(from: strip, to: $0).address]
                    + [Catalog.sendPan(from: strip, to: $0)?.address, Catalog.sendPanFollow(from: strip, to: $0)?.address]
                    .compactMap { $0 }
                    + [Catalog.sendTap(from: strip, to: $0)?.address].compactMap { $0 }
            } + [Catalog.dynamicsPosition(strip)?.address].compactMap { $0 }
        case .fedBy:
            strip.kind.feeders.flatMap(StripID.all).map { Catalog.sendLevel(from: $0, to: strip).address }
        case .members: StripKind.allCases.flatMap(StripID.all).compactMap(\.dcaMask)
        }
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

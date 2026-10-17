import Testing

@testable import ThumbmixCore

@MainActor
struct LowCutTests {
    private let kick = StripID(.input, 1)

    @Test func onlyInputChannelsHaveALowCut() {
        let lowCut = Catalog.lowCut(kick)
        #expect(lowCut?.on.address == "/ch/01/preamp/hpon")
        #expect(lowCut?.frequency.scale == .log(min: 20, max: 400, steps: 101))
        #expect(lowCut?.slope.scale == .choice(["12 dB/oct", "18 dB/oct", "24 dB/oct"]))
        #expect(Catalog.lowCut(StripID(.bus, 1)) == nil)
        #expect(Catalog.lowCut(StripID(.mainStereo)) == nil)
        #expect(Catalog.lowCut(StripID(.auxIn, 1)) == nil)
    }

    @Test func lowCutIsSyncedWithIntDefaultsInTheDemo() {
        #expect(Catalog.allAddresses().contains("/ch/32/preamp/hpslope"))
    }

    @Test func slopeSetsHowFastTheCutFalls() {
        let cutoff = 100.0
        for slope in 0...2 {
            let state = LowCutState(frequency: cutoff, slopeIndex: slope)
            #expect(abs(state.decibels(at: cutoff) + 3.01) < 0.05)
            #expect(abs(state.decibels(at: 10_000)) < 0.01)
            let decibelsPerOctave = Double(12 + 6 * slope)
            #expect(abs(state.decibels(at: cutoff / 4) + 2 * decibelsPerOctave) < 1)
        }
    }

    @Test func mirrorDrawsTheCutOnlyWhenItIsOn() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        let specs = Catalog.lowCut(kick)!
        mirror.apply(OSCMessage(specs.frequency.address, [.float(0.5)]))
        mirror.apply(OSCMessage(specs.slope.address, [.int(2)]))
        mirror.apply(OSCMessage(specs.on.address, [.int(0)]))
        #expect(mirror.lowCut(kick) == nil)
        mirror.apply(OSCMessage(specs.on.address, [.int(1)]))
        #expect(mirror.lowCut(kick)?.slopeIndex == 2)
        #expect(abs((mirror.lowCut(kick)?.frequency ?? 0) - 89.4) < 0.5)
    }

    /// Off, the graph still draws the cut as set, dashed: what switching it on brings back.
    @Test func mirrorKeepsTheCutAsSetWhileItIsOff() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        let specs = Catalog.lowCut(kick)!
        mirror.apply(OSCMessage(specs.frequency.address, [.float(0.5)]))
        mirror.apply(OSCMessage(specs.slope.address, [.int(2)]))
        #expect(mirror.lowCutAsSet(kick) == nil)
        mirror.apply(OSCMessage(specs.on.address, [.int(0)]))
        #expect(mirror.lowCutAsSet(kick)?.slopeIndex == 2)
        #expect(mirror.isLowCutOn(kick) == false)
        mirror.apply(OSCMessage(specs.on.address, [.int(1)]))
        #expect(mirror.isLowCutOn(kick))
    }

    /// The dashed slope ends where the cut stops showing, so it never runs on top of the curve.
    @Test func cutFadesOutAboveItsCutoff() {
        for slope in 0...2 {
            let state = LowCutState(frequency: 100, slopeIndex: slope)
            let hertz = state.hertz(whereCutIs: -0.5)
            #expect(hertz > 100)
            #expect(abs(state.decibels(at: hertz) + 0.5) < 0.001)
        }
    }
}

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
        #expect(Catalog.syncAddresses().contains("/ch/32/preamp/hpslope"))
        let demo = DemoState.values()
        #expect(demo["/ch/01/preamp/hpon"] == .int(0))
        #expect(demo["/ch/01/preamp/hpslope"] == .int(2))
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
}

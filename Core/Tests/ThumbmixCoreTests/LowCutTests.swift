import Testing

@testable import ThumbmixCore

@MainActor
struct LowCutTests {
    private let kick = StripID(.input, 1)

    @Test func onlyInputChannelsHaveALowCut() {
        let lowCut = Catalog.lowCut(kick)
        #expect(lowCut?.on.address == "/ch/01/preamp/hpon")
        #expect(lowCut?.frequency.scale == .log(min: 20, max: 400, steps: 101))
        #expect(Catalog.lowCut(StripID(.bus, 1)) == nil)
        #expect(Catalog.lowCut(StripID(.mainStereo)) == nil)
        #expect(Catalog.lowCut(StripID(.auxIn, 1)) == nil)
    }

    /// The desk's slope setting changes nothing (the user, 2026-10-22), so the app neither shows nor needs it.
    @Test func theCutNeedsNoSlopeAndFalls24DecibelsPerOctave() throws {
        #expect(!Catalog.allAddresses().contains("/ch/01/preamp/hpslope"))
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        let specs = Catalog.lowCut(kick)!
        mirror.apply(OSCMessage(specs.frequency.address, [.float(0.5)]))
        mirror.apply(OSCMessage(specs.on.address, [.int(1)]))
        let cut = try #require(mirror.lowCut(kick))
        #expect(abs(cut.decibels(at: cut.frequency) + 3.01) < 0.05)
        #expect(abs(cut.decibels(at: cut.frequency / 4) + 48) < 1)
        #expect(abs(cut.decibels(at: 10_000)) < 0.01)
    }

    @Test func mirrorDrawsTheCutOnlyWhenItIsOn() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        let specs = Catalog.lowCut(kick)!
        mirror.apply(OSCMessage(specs.frequency.address, [.float(0.5)]))
        mirror.apply(OSCMessage(specs.on.address, [.int(0)]))
        #expect(mirror.lowCut(kick) == nil)
        mirror.apply(OSCMessage(specs.on.address, [.int(1)]))
        #expect(abs((mirror.lowCut(kick)?.frequency ?? 0) - 89.4) < 0.5)
    }

    /// Off, the graph still draws the cut as set, dashed: what switching it on brings back.
    @Test func mirrorKeepsTheCutAsSetWhileItIsOff() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        let specs = Catalog.lowCut(kick)!
        mirror.apply(OSCMessage(specs.frequency.address, [.float(0.5)]))
        #expect(mirror.lowCutAsSet(kick) == nil)
        mirror.apply(OSCMessage(specs.on.address, [.int(0)]))
        #expect(mirror.lowCutAsSet(kick) != nil)
        #expect(mirror.isLowCutOn(kick) == false)
        mirror.apply(OSCMessage(specs.on.address, [.int(1)]))
        #expect(mirror.isLowCutOn(kick))
    }

    /// The dashed cut ends where it stops showing, so it never runs on top of the curve.
    @Test func cutFadesOutAboveItsCutoff() {
        let state = LowCutState(frequency: 100)
        let hertz = state.hertz(whereCutIs: -0.5)
        #expect(hertz > 100)
        #expect(abs(state.decibels(at: hertz) + 0.5) < 0.001)
    }
}

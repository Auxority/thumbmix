import Testing

@testable import ThumbmixCore

@MainActor
struct MirrorStripTests {
    private let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))

    @Test func nameFallsBackWhenBlank() {
        mirror.apply(OSCMessage("/ch/01/config/name", [.string("  ")]))
        #expect(mirror.name(StripID(.input, 1)) == "Ch 1")
        mirror.apply(OSCMessage("/ch/01/config/name", [.string("Kick")]))
        #expect(mirror.name(StripID(.input, 1)) == "Kick")
    }

    @Test func colorFromIndex() {
        mirror.apply(OSCMessage("/bus/02/config/color", [.int(11)]))
        #expect(mirror.color(StripID(.bus, 2)) == ConsoleColor(base: .yellow, inverted: true))
    }

    @Test func valueIsInRealUnitsAndNilUntilRead() {
        let threshold = Catalog.gate(StripID(.input, 3)).threshold
        #expect(mirror.value(threshold) == nil)
        mirror.apply(OSCMessage(threshold.address, [.float(0.5)]))
        #expect(mirror.value(threshold) == -40)
        let mode = Catalog.dynamics(StripID(.input, 3)).mode
        mirror.apply(OSCMessage(mode.address, [.int(1)]))
        #expect(mirror.value(mode) == 1)
    }

    @Test func mutedWhenOnIsZero() {
        mirror.apply(OSCMessage("/ch/05/mix/on", [.int(0)]))
        #expect(mirror.isMuted(StripID(.input, 5)))
    }

    @Test func unusedMeansUnnamedAndDown() {
        let strip = StripID(.input, 20)
        mirror.apply(OSCMessage(strip.name, [.string("")]))
        mirror.apply(OSCMessage(strip.fader, [.float(0)]))
        #expect(mirror.isUnused(strip))
        mirror.apply(OSCMessage(strip.fader, [.float(0.5)]))
        #expect(!mirror.isUnused(strip))
    }

    @Test func headampFromIndexAndSharing() {
        let (ch1, ch2, ch3) = (StripID(.input, 1), StripID(.input, 2), StripID(.input, 3))
        mirror.apply(OSCMessage(Catalog.headampIndex(ch1)!, [.int(32)]))
        mirror.apply(OSCMessage(Catalog.headampIndex(ch2)!, [.int(32)]))
        mirror.apply(OSCMessage(Catalog.headampIndex(ch3)!, [.int(-1)]))
        #expect(mirror.headamp(of: ch1) == 32)
        #expect(mirror.headamp(of: ch3) == nil)
        #expect(mirror.stripsSharingHeadamp(with: ch1) == [ch2])
        #expect(mirror.stripsSharingHeadamp(with: ch3) == [])
    }

    /// The desk can route aux 1-6 from inputs (`/config/routing/IN/AUX`, doc p.21): then an aux shares a preamp,
    /// and its 48V, with the channel on that input.
    @Test func anAuxRoutedFromAnInputSharesItsHeadamp() {
        let (ch1, aux1, aux2) = (StripID(.input, 1), StripID(.auxIn, 1), StripID(.auxIn, 2))
        mirror.apply(OSCMessage(Catalog.headampIndex(ch1)!, [.int(0)]))
        mirror.apply(OSCMessage(Catalog.headampIndex(aux1)!, [.int(0)]))
        mirror.apply(OSCMessage(Catalog.headampIndex(aux2)!, [.int(-1)]))
        #expect(mirror.headamp(of: aux1) == 0)
        #expect(mirror.headamp(of: aux2) == nil, "a line-level aux jack has no preamp")
        #expect(mirror.stripsSharingHeadamp(with: ch1) == [aux1])
        #expect(mirror.stripsSharingHeadamp(with: aux1) == [ch1])
        #expect(mirror.headamp(of: StripID(.fxReturn, 1)) == nil)
    }

    @Test func dcaBitZeroIsDCAOne() {
        mirror.apply(OSCMessage("/ch/01/grp/dca", [.int(0b101)]))
        #expect(mirror.isMember(StripID(.input, 1), ofDCA: 1))
        #expect(!mirror.isMember(StripID(.input, 1), ofDCA: 2))
        #expect(mirror.isMember(StripID(.input, 1), ofDCA: 3))
        #expect(mirror.dcaMembers(3).contains(StripID(.input, 1)))
    }
}

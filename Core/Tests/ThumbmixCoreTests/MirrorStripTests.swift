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
        mirror.apply(OSCMessage(Catalog.headampIndex(forInput: 1), [.int(32)]))
        mirror.apply(OSCMessage(Catalog.headampIndex(forInput: 2), [.int(32)]))
        mirror.apply(OSCMessage(Catalog.headampIndex(forInput: 3), [.int(-1)]))
        #expect(mirror.headamp(forInput: 1) == 32)
        #expect(mirror.headamp(forInput: 3) == nil)
        #expect(mirror.inputsSharingHeadamp(withInput: 1) == [2])
        #expect(mirror.inputsSharingHeadamp(withInput: 3) == [])
    }

    @Test func dcaBitZeroIsDCAOne() {
        mirror.apply(OSCMessage("/ch/01/grp/dca", [.int(0b101)]))
        #expect(mirror.isMember(StripID(.input, 1), ofDCA: 1))
        #expect(!mirror.isMember(StripID(.input, 1), ofDCA: 2))
        #expect(mirror.isMember(StripID(.input, 1), ofDCA: 3))
        #expect(mirror.dcaMembers(3).contains(StripID(.input, 1)))
    }
}

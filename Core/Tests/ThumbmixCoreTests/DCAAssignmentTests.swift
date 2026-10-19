import FakeM32
import Testing

@testable import ThumbmixCore

/// A DCA's Members tab assigns strips with one chip per row (mock 2026-10-17-dca-members, D with I3 marks). The demo
/// desk has the drums (Ch 1-6) on DCA 1 and the linked guitars (Ch 9-10) on DCA 2.
@MainActor
struct DCAAssignmentTests {
    private let kick = StripID(.input, 1)
    private let gtrL = StripID(.input, 9)
    private let gtrR = StripID(.input, 10)

    /// The desk holds only Gtr L on DCA 2, as after unlinking, reassigning one side, and linking again.
    private func withHalfAssignedGuitars(body: (FakeM32, ConsoleMirror) async throws -> Void) async throws {
        try await withLiveDesk(before: { $0.deskChange(gtrR.dcaMask!, .int(0)) }, body: body)
    }

    @Test func aStripReadsAssignedOrNot() async throws {
        try await withLiveDesk { _, mirror in
            #expect(mirror.assignment(of: kick, to: .dca(1)) == .assigned)
            #expect(mirror.assignment(of: kick, to: .dca(2)) == .unassigned)
        }
    }

    @Test func aPairTheDeskAssignedOnOneSideNamesThatSide() async throws {
        try await withHalfAssignedGuitars { _, mirror in
            #expect(mirror.assignment(of: gtrL, to: .dca(2)) == .leftOnly)
            #expect(mirror.assignment(of: gtrL, to: .dca(3)) == .unassigned)
        }
    }

    @Test func anUnreadMaskIsUnread() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        #expect(mirror.assignment(of: kick, to: .dca(1)) == .unread)
    }

    /// The mask holds all 8 DCAs: a tap changes only this DCA's bit.
    @Test func aTapFlipsOnlyThisDCAsBit() async throws {
        try await withLiveDesk { fake, mirror in
            mirror.toggleAssignment(of: kick, to: .dca(3))
            #expect(await eventually { fake.value(at: kick.dcaMask!) == .int(0b101) })

            mirror.toggleAssignment(of: kick, to: .dca(1))
            #expect(await eventually { fake.value(at: kick.dcaMask!) == .int(0b100) })
        }
    }

    /// The doc doesn't say whether the desk links DCA assignment; half a stereo source on a DCA is never wanted.
    @Test func aLinkedPairAssignsBothSides() async throws {
        try await withLiveDesk { fake, mirror in
            mirror.toggleAssignment(of: gtrL, to: .dca(1))
            #expect(await eventually { fake.value(at: gtrL.dcaMask!) == .int(0b011) })
            #expect(await eventually { fake.value(at: gtrR.dcaMask!) == .int(0b011) })
        }
    }

    @Test func aHalfAssignedPairTapsToBothAssigned() async throws {
        try await withHalfAssignedGuitars { fake, mirror in
            mirror.toggleAssignment(of: gtrL, to: .dca(2))
            #expect(await eventually { fake.value(at: gtrR.dcaMask!) == .int(0b010) })
            #expect(fake.value(at: gtrL.dcaMask!) == .int(0b010))
        }
    }

    /// Unused strips fold, but an assigned one stays in view: its chip is the only place to see and undo it.
    @Test func anAssignedStripNeverFolds() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        let (ch20, ch21) = (StripID(.input, 20), StripID(.input, 21))
        for strip in [ch20, ch21] {
            mirror.apply(OSCMessage(strip.name, [.string("")]))
            mirror.apply(OSCMessage(strip.fader, [.float(0)]))
        }
        mirror.apply(OSCMessage(ch20.dcaMask!, [.int(0b1)]))
        mirror.apply(OSCMessage(ch21.dcaMask!, [.int(0)]))

        let unused = mirror.unusedStrips(notIn: .dca(1))

        #expect(!unused.contains(ch20))
        #expect(unused.contains(ch21))
    }

    /// One chip assigns both sides, so a linked pair is one row even where the overview splits it (faders not linked).
    @Test func aLinkedPairIsOneRowWhateverTheFaderLink() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        mirror.apply(OSCMessage(gtrL.linkAddress!, [.int(1)]))
        let strips = [StripID(.input, 8), gtrL, gtrR]
        #expect(mirror.overviewItems(strips, showUnused: true).count == 3, "the overview splits it")

        #expect(mirror.assignmentRows(strips) == [.strip(StripID(.input, 8), .full), .pair(gtrL)])
    }

    @Test func everyStripWithAMaskIsListedInDeskOrder() {
        #expect(ConsoleMirror.dcaAssignableStrips.first == StripID(.input, 1))
        #expect(ConsoleMirror.dcaAssignableStrips.last == StripID(.bus, 16))
        #expect(ConsoleMirror.dcaAssignableStrips.count == 32 + 8 + 8 + 16)
        #expect(ConsoleMirror.dcaAssignableStrips.allSatisfy { $0.dcaMask != nil })
    }
}

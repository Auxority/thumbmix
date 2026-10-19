import FakeM32
import Testing

@testable import ThumbmixCore

/// Every strip has a solo switch, `/-stat/solosw/01…80` in the desk's strip order (doc p.64).
@MainActor
struct SoloTests {
    @Test func soloSwitchesFollowTheDesksStripOrder() {
        #expect(StripID(.input, 1).solo == "/-stat/solosw/01")
        #expect(StripID(.input, 32).solo == "/-stat/solosw/32")
        #expect(StripID(.auxIn, 1).solo == "/-stat/solosw/33")
        #expect(StripID(.fxReturn, 1).solo == "/-stat/solosw/41")
        #expect(StripID(.bus, 16).solo == "/-stat/solosw/64")
        #expect(StripID(.matrix, 1).solo == "/-stat/solosw/65")
        #expect(StripID(.mainStereo).solo == "/-stat/solosw/71")
        #expect(StripID(.mainMono).solo == "/-stat/solosw/72")
        #expect(StripID(.dca, 8).solo == "/-stat/solosw/80")
    }

    /// S sits beside the slim fader on every tab, so solo is read on connect, like mute: read only with the Mix tab,
    /// a strip opened on Fed by, or a resync while on EQ, left S unread, and an unread switch ignores taps.
    @Test func soloWorksWithoutOpeningTheMixTab() async throws {
        try await withLiveDesk { fake, mirror in
            let bus = StripID(.bus, 1)
            #expect(mirror.cell(bus.solo).argument == .int(0), "read before going live")

            mirror.toggleSolo(bus)

            #expect(await eventually { fake.value(at: bus.solo) == .int(1) })
        }
    }

    @Test func soloTogglesTheStrip() async throws {
        try await withLiveDesk { fake, mirror in
            let kick = StripID(.input, 1)
            await openTab(.mix, of: kick, in: mirror)
            #expect(!mirror.isSoloed(kick))

            mirror.toggleSolo(kick)

            #expect(await eventually { fake.value(at: kick.solo) == .int(1) })
            #expect(mirror.isSoloed(kick))
        }
    }

    /// The doc doesn't say whether the desk links solo; half a stereo source soloed is never wanted, and writing the
    /// partner too is harmless if the desk does copy it.
    @Test func aLinkedPairSolosBothSides() async throws {
        try await withLiveDesk { fake, mirror in
            let gtrL = StripID(.input, 9)
            await openTab(.mix, of: gtrL, in: mirror)

            mirror.toggleSolo(gtrL)

            // Both sides go out in one tick, in no set order.
            #expect(await eventually { fake.value(at: StripID(.input, 10).solo) == .int(1) })
            #expect(await eventually { fake.value(at: gtrL.solo) == .int(1) })
        }
    }

    /// The fake desk plays the desk's CLEAR SOLO (doc p.69), so the app's Clear can be tested end to end.
    @Test func clearSoloSilencesEverySwitch() async throws {
        try await withLink { fake, link in
            fake.deskChange(StripID(.input, 1).solo, .int(1))
            fake.deskChange(StripID(.bus, 3).solo, .int(1))

            link.send(OSCMessage("/-action/clearsolo", [.int(1)]))

            #expect(await eventually { fake.value(at: StripID(.input, 1).solo) == .int(0) })
            #expect(await eventually { fake.value(at: StripID(.bus, 3).solo) == .int(0) })
        }
    }

    /// Exclusive solo (doc p.21) keeps one solo at a time. Assumed to hold for OSC sets too until m32-probe says.
    @Test func exclusiveSoloKeepsOnlyTheLast() async throws {
        try await withLink { fake, link in
            fake.deskChange("/config/solo/exclusive", .int(1))
            fake.deskChange(StripID(.input, 1).solo, .int(1))

            link.send(OSCMessage(StripID(.input, 2).solo, [.int(1)]))

            #expect(await eventually { fake.value(at: StripID(.input, 2).solo) == .int(1) })
            #expect(await eventually { fake.value(at: StripID(.input, 1).solo) == .int(0) })
        }
    }
}

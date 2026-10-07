import FakeM32
import Testing

@testable import ThumbmixCore

/// The fake copies a shared section to the linked partner without pushing that copy back to the sender, like a
/// desk that doesn't echo OSC-caused changes: only the mirror's re-read of the partner can bring it in.
@MainActor
struct LinkSyncTests {
    @Test func aFaderEditReachesTheLinkedPartnerThroughTheReRead() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        let gtrL = Catalog.fader(StripID(.input, 9))
        let gtrR = Catalog.fader(StripID(.input, 10))

        mirror.set(gtrL.address, .float(0.25))

        #expect(await eventually { fake.value(at: gtrR.address) == .float(0.25) }, "the fake copies to the partner")
        #expect(await eventually { mirror.cell(gtrR.address).argument == .float(0.25) })
        #expect(!fake.receivedSets.contains { $0.address == gtrR.address }, "the app wrote one side only")
    }

    /// Unconfirmed on a real desk: if it doesn't copy an OSC edit to the partner, the app repairs the partner
    /// once the re-read shows it, then writes both sides itself for the rest of the session.
    @Test func aDeskThatDoesNotCopyGetsBothSidesWritten() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        fake.copiesLinkedEdits = false
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        let gtrL = Catalog.fader(StripID(.input, 9)).address
        let gtrR = Catalog.fader(StripID(.input, 10)).address

        mirror.set(gtrL, .float(0.25))
        #expect(await eventually { fake.value(at: gtrR) == .float(0.25) }, "the partner is repaired")

        mirror.set(gtrL, .float(0.6))
        #expect(await eventually { fake.receivedSets.contains(OSCMessage(gtrR, [.float(0.6)])) }, "written directly")
        #expect(mirror.cell(gtrR).argument == .float(0.6))
    }

    /// Only fader, mute and sends are seen linked on the desk; the rest is unverified, so a partner that didn't
    /// follow is never overwritten: the app shows that section per side instead.
    @Test func anUnverifiedSectionThatDoesNotFollowIsShownPerSideNotWritten() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        fake.copiesLinkedEdits = false
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        let gainL = Catalog.eqBand(StripID(.input, 9), 2).gain.address
        let gainR = Catalog.eqBand(StripID(.input, 10), 2).gain.address
        let before = fake.value(at: gainR)
        #expect(mirror.isShared(.eq))

        mirror.set(gainL, .float(0.9))

        #expect(await eventually { !mirror.isShared(.eq) }, "EQ now shows per side")
        #expect(fake.value(at: gainR) == before)
        #expect(!fake.receivedSets.contains { $0.address == gainR })
        #expect(mirror.partnerAddress(of: gainL) == nil, "no more re-reads of a side that's set on its own")
    }

    @Test func panIsNotCopied() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        let right = try #require(StripID(.input, 10).pan)

        mirror.set(try #require(StripID(.input, 9).pan), .float(0.3))
        try await Task.sleep(for: .milliseconds(500))

        #expect(fake.value(at: right) == .float(1))
    }

    /// Linking on the desk pans the sides hard left and right; the app reads both pans back.
    @Test func linkingPansTheSidesApart() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        let kick = StripID(.input, 1)

        mirror.setLinked(kick, true)

        #expect(await eventually { fake.value(at: "/config/chlink/1-2") == .int(1) })
        #expect(await eventually { mirror.cell(try! #require(kick.pan)).argument == .float(0) })
        #expect(await eventually { mirror.cell(try! #require(StripID(.input, 2).pan)).argument == .float(1) })
        mirror.setLinked(kick, false)
        #expect(await eventually { fake.value(at: "/config/chlink/1-2") == .int(0) })
    }
}

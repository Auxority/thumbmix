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

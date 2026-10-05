import FakeM32
import Foundation
import Testing

@testable import ThumbmixCore

@MainActor
struct RTATests {
    @Test func sourceNumbersFollowTheDoc() {
        // /-prefs/rta/source, doc p.58: 2-33 Ch01-32, 34-41 Aux, 42-49 FX1L-FX4R, 50-65 Bus, 72 Main, 73 Mono.
        #expect(StripID(.input, 1).rtaSource == 2)
        #expect(StripID(.input, 32).rtaSource == 33)
        #expect(StripID(.auxIn, 1).rtaSource == 34)
        #expect(StripID(.fxReturn, 8).rtaSource == 49)
        #expect(StripID(.bus, 16).rtaSource == 65)
        #expect(StripID(.mainStereo).rtaSource == 72)
        #expect(StripID(.mainMono).rtaSource == 73)
        #expect(StripID(.dca, 1).rtaSource == nil, "a DCA carries no audio")
    }

    @Test func spectrumBlobDecodesTheDocsExample() {
        // "008000c0" decodes to -128.0 and -64.0 dB (doc p.19): little-endian int16 / 256.
        var blob = Data([50, 0, 0, 0, 0x00, 0x80, 0x00, 0xC0])
        blob.append(Data(repeating: 0, count: 196))
        let decibels = MeterBlob.rtaDecibels(from: blob)
        #expect(decibels.count == 100)
        #expect(decibels[0] == -128)
        #expect(decibels[1] == -64)
        #expect(decibels[99] == 0)
        #expect(MeterBlob.rtaDecibels(from: MeterBlob.encodeRTA(decibels)) == decibels)
    }

    @Test func bandsSpanTheDocsRange() {
        #expect(RTA.bandFrequency(0) == 20)
        #expect(abs(RTA.bandFrequency(99) - 18_660) < 1)
    }

    private func liveMirror(_ port: UInt16) async -> ConsoleMirror {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port, timing: .fast))
        mirror.start()
        _ = await eventually(timeout: .seconds(10)) { mirror.isLive }
        return mirror
    }

    @Test func followingPointsTheDeskRTAAndReleasingPutsItBack() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        fake.deskChange(RTA.source, .int(50))
        fake.deskChange(RTA.position, .int(0))
        let mirror = await liveMirror(port)
        defer { mirror.stop() }
        #expect(await eventually { mirror.cell(RTA.source).argument == .int(50) })

        mirror.followRTA(StripID(.input, 1))

        #expect(await eventually { fake.value(at: RTA.source) == .int(2) && fake.value(at: RTA.position) == .int(1) })
        #expect(await eventually { mirror.spectrum.decibels.count == 100 })

        mirror.releaseRTA()

        #expect(await eventually { fake.value(at: RTA.source) == .int(50) && fake.value(at: RTA.position) == .int(0) })
        #expect(mirror.spectrum.decibels.isEmpty)
    }

    @Test func aChangeMadeOnTheDeskMeanwhileIsKept() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port)
        defer { mirror.stop() }
        mirror.followRTA(StripID(.input, 1))
        #expect(await eventually { fake.value(at: RTA.source) == .int(2) })
        // Right after the app's own edit the mirror ignores pushes for that address (EditHolds); the
        // engineer reaching for the desk happens later than that.
        try await Task.sleep(for: ConsoleMirror.editHold + .milliseconds(100))

        fake.deskChange(RTA.source, .int(66))
        #expect(await eventually { mirror.cell(RTA.source).argument == .int(66) })
        mirror.releaseRTA()

        // The position still shows ours, so it is restored; once it is, the source decision has been made too.
        #expect(await eventually { fake.value(at: RTA.position) == .int(0) })
        #expect(fake.value(at: RTA.source) == .int(66))
    }

    @Test func switchingChannelsKeepsTheOriginalToRestore() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        fake.deskChange(RTA.source, .int(72))
        let mirror = await liveMirror(port)
        defer { mirror.stop() }
        #expect(await eventually { mirror.cell(RTA.source).argument == .int(72) })

        mirror.followRTA(StripID(.input, 1))
        #expect(await eventually { fake.value(at: RTA.source) == .int(2) })
        mirror.followRTA(StripID(.input, 3))
        #expect(await eventually { fake.value(at: RTA.source) == .int(4) })
        mirror.releaseRTA()

        #expect(await eventually { fake.value(at: RTA.source) == .int(72) })
    }
}

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

    /// Release judges by what the mirror shows. An audit question asked just before the app's set, answered after
    /// the hold, shows the old value until the re-read answers, so these tests leave the audit out (it has its own).
    private func withRTADesk(
        before: (FakeM32) -> Void = { _ in }, _ body: (FakeM32, ConsoleMirror) async throws -> Void
    ) async throws {
        try await withLiveDesk(auditAddresses: [], before: before, body)
    }

    @Test func followingPointsTheDeskRTAAndReleasingPutsItBack() async throws {
        try await withRTADesk(before: { fake in
            fake.deskChange(RTA.source, .int(50))
            fake.deskChange(RTA.position, .int(0))
        }) { fake, mirror in
            #expect(await eventually { mirror.cell(RTA.source).argument == .int(50) })

            mirror.followRTA(StripID(.input, 1))

            #expect(await eventually { fake.value(at: RTA.source) == .int(2) && fake.value(at: RTA.position) == .int(1) })
            #expect(await eventually { mirror.spectrum.decibels.count == 100 })

            mirror.releaseRTA()

            #expect(await eventually { fake.value(at: RTA.source) == .int(50) && fake.value(at: RTA.position) == .int(0) })
            #expect(mirror.spectrum.decibels.isEmpty)
        }
    }

    /// The stream expires on the desk after 10 s, so it is renewed exactly while the app borrows the RTA.
    @Test func theRTAStreamIsRenewedOnlyWhileFollowing() async throws {
        try await withRTADesk { _, mirror in
            #expect(mirror.link.renewals().contains(OSCMessage("/xremote")))
            #expect(!mirror.link.renewals().contains(RTA.subscription))

            mirror.followRTA(StripID(.input, 1))
            #expect(mirror.link.renewals().contains(RTA.subscription))
            #expect(mirror.link.renewals().contains(OSCMessage("/xremote")))

            mirror.releaseRTA()
            #expect(!mirror.link.renewals().contains(RTA.subscription))
        }
    }

    /// The offline demo's spectrum is measured "after EQ" like the desk's: a band boosted, then cut, by 15 dB
    /// moves the spectrum there far more than the fake's own wobble (a few dB).
    @Test func theDemoSpectrumFollowsTheEQ() async throws {
        try await withLiveDesk { fake, mirror in
            let kick = StripID(.input, 1)
            await openTab(.eq, of: kick, in: mirror)
            let gain = Catalog.eqBand(kick, 1).gain
            let bandFrequency = try #require(mirror.eqBands(kick).first?.frequency)
            let index = (0..<RTA.bandCount).min { abs(RTA.bandFrequency($0) - bandFrequency) < abs(RTA.bandFrequency($1) - bandFrequency) }!
            mirror.followRTA(kick)
            #expect(await eventually { mirror.spectrum.decibels.count == RTA.bandCount })

            let flat = mirror.spectrum.decibels[index]

            // Waits for a spectrum each edit shaped: one sampled after a fixed sleep can predate it on a slow runner.
            mirror.set(gain.address, gain.scale.argument(fromNormalized: 1))
            #expect(await eventually { mirror.spectrum.decibels[index] - flat > 10 }, "boost at \(Int(bandFrequency)) Hz")
            let boosted = mirror.spectrum.decibels[index]
            mirror.set(gain.address, gain.scale.argument(fromNormalized: 0))

            #expect(
                await eventually { boosted - mirror.spectrum.decibels[index] > 20 },
                "boosted \(boosted) dB, cut \(mirror.spectrum.decibels[index]) dB at \(Int(bandFrequency)) Hz")
        }
    }

    @Test func aChangeMadeOnTheDeskMeanwhileIsKept() async throws {
        try await withRTADesk { fake, mirror in
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
    }

    @Test func switchingChannelsKeepsTheOriginalToRestore() async throws {
        try await withRTADesk(before: { fake in
            fake.deskChange(RTA.source, .int(72))
        }) { fake, mirror in
            #expect(await eventually { mirror.cell(RTA.source).argument == .int(72) })

            mirror.followRTA(StripID(.input, 1))
            #expect(await eventually { fake.value(at: RTA.source) == .int(2) })
            mirror.followRTA(StripID(.input, 3))
            #expect(await eventually { fake.value(at: RTA.source) == .int(4) })
            mirror.releaseRTA()

            #expect(await eventually { fake.value(at: RTA.source) == .int(72) })
        }
    }
}

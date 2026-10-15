import FakeM32
import Testing

@testable import ThumbmixCore

/// Unused strips fold into one row at the end of a list (mocks 2026-10-14-unused-strips, A1 + open in place).
/// Unused: unnamed, fader at −∞; on Sends and Fed by also the send there at −∞, so a live send never hides.
@MainActor
struct UnusedFoldTests {
    @Test func theLabelJoinsNeighboursIntoRanges() {
        let strips = [3, 6, 8, 10, 13, 14].map { StripID(.input, $0) } + (3...8).map { StripID(.auxIn, $0) }
        #expect(UnusedLabel.text(strips) == "Ch\u{a0}3, 6, 8, 10, 13\u{2060}–\u{2060}14, Aux\u{a0}3\u{2060}–\u{2060}8")
    }

    /// A range never wraps inside: word joiners hold "13–14" together, a no-break space keeps "Ch 3".
    @Test func aRangeReadsAsOneWord() {
        let text = UnusedLabel.text((17...32).map { StripID(.input, $0) })
        #expect(text.replacingOccurrences(of: "\u{2060}", with: "").replacingOccurrences(of: "\u{a0}", with: " ") == "Ch 17–32")
    }

    @Test func theOverviewFoldsUnnamedStripsWithTheirFaderDown() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        for number in [3, 4] { fake.deskChange(StripID(.input, number).name, .string("")) }
        fake.deskChange(Catalog.fader(StripID(.input, 3)).address, .float(0))
        fake.deskChange(Catalog.fader(StripID(.input, 4)).address, .float(0.75))
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        let folded = mirror.unusedStrips(StripID.all(.input), where: mirror.isUnused)
        #expect(folded.contains(StripID(.input, 3)))
        #expect(!folded.contains(StripID(.input, 4)), "a fader that's up means it's in use")
        #expect(mirror.unusedStrips([StripID(.mainStereo), StripID(.mainMono)]) { _ in true }.isEmpty, "mains never fold")
    }

    @Test func aLinkedPairFoldsOnlyWhenBothSidesAreUnused() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let (left, right) = (StripID(.input, 23), StripID(.input, 24))
        for side in [left, right] {
            fake.deskChange(side.name, .string(""))
            fake.deskChange(Catalog.fader(side).address, .float(0))
        }
        fake.deskChange(right.name, .string("Spare R"))
        fake.deskChange("/config/chlink/23-24", .int(1))
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        #expect(mirror.unusedStrips([left, right], where: mirror.isUnused).isEmpty)
    }

    /// Ch 21 is unnamed with its fader down, but its send to Mon 1 is up: it stays reachable (#67).
    @Test func fedByKeepsAnUnusedSourceWhoseSendIsUp() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mon = StripID(.bus, 1)
        for number in [21, 22] {
            let source = StripID(.input, number)
            fake.deskChange(source.name, .string(""))
            fake.deskChange(Catalog.fader(source).address, .float(0))
        }
        fake.deskChange(Catalog.sendLevel(from: StripID(.input, 21), to: mon).address, .float(0.6))
        fake.deskChange(Catalog.sendLevel(from: StripID(.input, 22), to: mon).address, .float(0))
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        await openTab(.fedBy, of: mon, in: mirror)
        let folded = mirror.unusedSources(of: mon)
        #expect(!folded.contains(StripID(.input, 21)))
        #expect(folded.contains(StripID(.input, 22)))
    }

    /// The desk keeps one tap point per pair of buses, so a pair shares one row's ›: it folds only as a whole.
    @Test func sendsFoldAPairOfBusesOnlyWhenBothAreUnused() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let vox = StripID(.input, 1)
        for number in 13...16 {
            let bus = StripID(.bus, number)
            fake.deskChange(bus.name, .string(""))
            fake.deskChange(Catalog.fader(bus).address, .float(0))
            fake.deskChange(Catalog.sendLevel(from: vox, to: bus).address, .float(0))
        }
        fake.deskChange(Catalog.sendLevel(from: vox, to: StripID(.bus, 14)).address, .float(0.5))
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        await openTab(.sends, of: vox, in: mirror)
        let folded = mirror.unusedSendTargets(of: vox)
        #expect(folded.contains(StripID(.bus, 15)) && folded.contains(StripID(.bus, 16)))
        #expect(!folded.contains(StripID(.bus, 13)), "its partner's send is up")
    }

    @Test func anUnreadLevelNeverFolds() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        #expect(mirror.unusedSources(of: StripID(.bus, 1)).isEmpty, "Fed by not read yet: unknown isn't unused")
    }
}

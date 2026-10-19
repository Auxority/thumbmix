import FakeM32
import Testing

@testable import ThumbmixCore

/// A stroke on the overview's names, played against the fake desk: the run reaches the desk, a push during the
/// stroke doesn't fight the finger, and Exclusive solo waits for the engineer's answer.
@MainActor
struct SoloStrokeMirrorTests {
    private func inputRows(_ mirror: ConsoleMirror) -> [OverviewItem] {
        mirror.overviewItems(StripID.all(.input), showUnused: true)
    }

    private func row(_ number: Int, in rows: [OverviewItem]) -> Int {
        rows.firstIndex { $0.holds(StripID(.input, number)) }!
    }

    private func soloed(_ fake: FakeM32, _ numbers: ClosedRange<Int>) -> Bool {
        numbers.allSatisfy { fake.value(at: StripID(.input, $0).solo) == .int(1) }
    }

    @Test func aStrokeSolosARunOnTheDesk() async throws {
        try await withLiveDesk { fake, mirror in
            let rows = inputRows(mirror)
            #expect(mirror.beginSoloStroke(rows, at: row(1, in: rows)) == [row(1, in: rows)])
            for number in 2...7 { _ = mirror.moveSoloStroke(to: row(number, in: rows)) }
            #expect(!mirror.endSoloStroke())

            #expect(await eventually { soloed(fake, 1...7) })
            #expect(mirror.soloLook(rows[row(4, in: rows)]) == .soloed)
        }
    }

    /// The finger owns every switch it passed until just after lift; then the desk's value is read back and wins.
    @Test func theDeskWinsAfterTheStroke() async throws {
        try await withLiveDesk { fake, mirror in
            let rows = inputRows(mirror)
            let snare = StripID(.input, 2)
            _ = mirror.beginSoloStroke(rows, at: row(1, in: rows))
            _ = mirror.moveSoloStroke(to: row(2, in: rows))
            #expect(await eventually { fake.value(at: snare.solo) == .int(1) })
            fake.deskChange(snare.solo, .int(0))

            _ = mirror.endSoloStroke()

            #expect(await eventually { mirror.cell(snare.solo).argument == .int(0) })
        }
    }

    @Test func exclusiveSoloAsksOnLift() async throws {
        try await withLiveDesk(
            before: { $0.deskChange(Catalog.exclusiveSolo, .int(1)) },
            body: { fake, mirror in
                let rows = inputRows(mirror)
                _ = mirror.beginSoloStroke(rows, at: row(1, in: rows))
                _ = mirror.moveSoloStroke(to: row(3, in: rows))
                #expect(mirror.soloLook(rows[row(2, in: rows)]) == .pending)

                #expect(mirror.endSoloStroke())
                #expect(await eventually { soloed(fake, 1...1) })
                #expect(fake.value(at: StripID(.input, 2).solo) == .int(0))

                mirror.answerExclusiveSolo(turnOff: true)

                #expect(await eventually { soloed(fake, 1...3) })
                #expect(fake.value(at: Catalog.exclusiveSolo) == .int(0))
            })
    }

    /// The desk would drop each held solo again if Exclusive were still on when they arrive.
    @Test func turnOffReachesTheDeskBeforeTheHeldSolos() async throws {
        try await withLiveDesk(
            before: { $0.deskChange(Catalog.exclusiveSolo, .int(1)) },
            body: { fake, mirror in
                let rows = inputRows(mirror)
                _ = mirror.beginSoloStroke(rows, at: row(1, in: rows))
                _ = mirror.moveSoloStroke(to: row(2, in: rows))
                _ = mirror.endSoloStroke()

                mirror.answerExclusiveSolo(turnOff: true)

                #expect(await eventually { soloed(fake, 2...2) })
                let addresses = fake.receivedSets.map(\.address)
                let exclusive = try #require(addresses.firstIndex(of: Catalog.exclusiveSolo))
                #expect(exclusive < addresses.lastIndex(of: StripID(.input, 2).solo)!)
            })
    }

    @Test func keepLeavesOneSoloAndAsksNoMore() async throws {
        try await withLiveDesk(
            before: { $0.deskChange(Catalog.exclusiveSolo, .int(1)) },
            body: { fake, mirror in
                let rows = inputRows(mirror)
                _ = mirror.beginSoloStroke(rows, at: row(1, in: rows))
                _ = mirror.moveSoloStroke(to: row(3, in: rows))
                _ = mirror.endSoloStroke()

                mirror.answerExclusiveSolo(turnOff: false)

                #expect(mirror.keepsExclusiveSolo)
                #expect(mirror.soloLook(rows[row(2, in: rows)]) == .off)
                _ = mirror.beginSoloStroke(rows, at: row(5, in: rows))
                _ = mirror.moveSoloStroke(to: row(6, in: rows))
                #expect(!mirror.endSoloStroke())
                #expect(fake.value(at: Catalog.exclusiveSolo) == .int(1))
            })
    }

    /// The spec: while contact is lost the stroke is off. A stroke left open would hold every switch it listed, so the
    /// desk's solos would never show again and no later stroke could start.
    @Test func lostContactEndsTheStroke() async throws {
        try await withLiveDesk { fake, mirror in
            let rows = inputRows(mirror)
            _ = mirror.beginSoloStroke(rows, at: row(1, in: rows))
            _ = mirror.moveSoloStroke(to: row(2, in: rows))
            fake.stop()

            #expect(await eventually { !mirror.isLive })
            #expect(mirror.soloStroke == nil)
        }
    }

    /// Clear during a stroke (a second thumb on the bar) wins: the stroke ends and the desk's cleared solos show.
    @Test func clearEndsAHeldStroke() async throws {
        try await withLiveDesk { fake, mirror in
            let rows = inputRows(mirror)
            _ = mirror.beginSoloStroke(rows, at: row(1, in: rows))
            _ = mirror.moveSoloStroke(to: row(3, in: rows))
            #expect(await eventually { soloed(fake, 1...3) })

            mirror.clearSolo()

            #expect(mirror.soloStroke == nil)
            #expect(await eventually { mirror.soloedCount == 0 })
        }
    }

    /// The overview went away mid-stroke: the switches it held show the desk's values again.
    @Test func abandoningReleasesTheHolds() async throws {
        try await withLiveDesk { fake, mirror in
            let rows = inputRows(mirror)
            let tom2 = StripID(.input, 5)
            _ = mirror.beginSoloStroke(rows, at: row(1, in: rows))

            mirror.abandonSoloStroke()
            fake.deskChange(tom2.solo, .int(1))

            #expect(mirror.soloStroke == nil)
            #expect(await eventually { mirror.cell(tom2.solo).argument == .int(1) })
        }
    }

    /// Contact lost before the answer: nothing held back is ever written, and nothing is asked.
    @Test func lostContactDropsTheHeldSolos() async throws {
        try await withLiveDesk(
            before: { $0.deskChange(Catalog.exclusiveSolo, .int(1)) },
            body: { fake, mirror in
                let rows = inputRows(mirror)
                _ = mirror.beginSoloStroke(rows, at: row(1, in: rows))
                _ = mirror.moveSoloStroke(to: row(3, in: rows))
                fake.stop()
                #expect(await eventually { !mirror.isLive })

                #expect(!mirror.endSoloStroke())
                #expect(mirror.soloLook(rows[row(2, in: rows)]) != .pending)
            })
    }
}

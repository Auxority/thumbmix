import FakeM32
import Testing

@testable import ThumbmixCore

/// A stroke on the overview's names, played against the fake desk: the run reaches the desk, a push during the
/// stroke doesn't fight the finger, and Exclusive solo waits for the engineer's answer.
@MainActor
struct SoloStrokeMirrorTests {
    private func row(_ number: Int, in rows: [OverviewItem]) -> Int {
        rows.firstIndex { $0.holds(StripID(.input, number)) }!
    }

    /// Holds input `from` and drags row by row to input `to`, the finger still down; returns the listed rows.
    @discardableResult
    private func stroke(_ mirror: ConsoleMirror, from: Int, to: Int) -> [OverviewItem] {
        let rows = mirror.overviewItems(StripID.all(.input), showUnused: true)
        _ = mirror.beginSoloStroke(rows, at: row(from, in: rows))
        for number in stride(from: from, through: to, by: from <= to ? 1 : -1) {
            _ = mirror.moveSoloStroke(to: row(number, in: rows))
        }
        return rows
    }

    private func soloed(_ fake: FakeM32, _ numbers: ClosedRange<Int>) -> Bool {
        numbers.allSatisfy { fake.value(at: StripID(.input, $0).solo) == .int(1) }
    }

    @Test func aStrokeSolosARunOnTheDesk() async throws {
        try await withLiveDesk { fake, mirror in
            let rows = stroke(mirror, from: 1, to: 7)
            #expect(!mirror.endSoloStroke())

            #expect(await eventually { soloed(fake, 1...7) })
            #expect(mirror.soloLook(rows[row(4, in: rows)]) == .soloed)
        }
    }

    /// The finger owns every switch it passed until just after lift; then the desk's value is read back and wins.
    @Test func theDeskWinsAfterTheStroke() async throws {
        try await withLiveDesk { fake, mirror in
            let snare = StripID(.input, 2)
            stroke(mirror, from: 1, to: 2)
            #expect(await eventually { fake.value(at: snare.solo) == .int(1) })
            fake.deskChange(snare.solo, .int(0))

            _ = mirror.endSoloStroke()

            #expect(await eventually { mirror.cell(snare.solo).argument == .int(0) })
        }
    }

    /// Turn off reaches the desk before the held solos: it would drop each of them again if they came first.
    @Test func exclusiveSoloAsksOnLift() async throws {
        try await withLiveDesk(setting: [Catalog.exclusiveSolo]) { fake, mirror in
            let rows = stroke(mirror, from: 1, to: 3)
            #expect(mirror.soloLook(rows[row(2, in: rows)]) == .pending)

            #expect(mirror.endSoloStroke())
            #expect(await eventually { soloed(fake, 1...1) })
            #expect(fake.value(at: StripID(.input, 2).solo) == .int(0))

            mirror.answerExclusiveSolo(turnOff: true)

            #expect(await eventually { soloed(fake, 1...3) })
            let addresses = fake.receivedSets.map(\.address)
            let exclusive = try #require(addresses.firstIndex(of: Catalog.exclusiveSolo))
            #expect(exclusive < addresses.lastIndex(of: StripID(.input, 2).solo)!)
        }
    }

    @Test func keepLeavesOneSoloAndAsksNoMore() async throws {
        try await withLiveDesk(setting: [Catalog.exclusiveSolo]) { fake, mirror in
            let rows = stroke(mirror, from: 1, to: 3)
            _ = mirror.endSoloStroke()

            mirror.answerExclusiveSolo(turnOff: false)

            #expect(mirror.keepsExclusiveSolo)
            #expect(mirror.soloLook(rows[row(2, in: rows)]) == .off)
            stroke(mirror, from: 5, to: 6)
            #expect(!mirror.endSoloStroke())
            #expect(fake.value(at: Catalog.exclusiveSolo) == .int(1))
        }
    }

    /// The spec: while contact is lost the stroke is off. Left open it would hold every switch it listed, so the desk's
    /// solos would never show again; nothing held back is written, and nothing is asked.
    @Test func lostContactEndsTheStroke() async throws {
        try await withLiveDesk(setting: [Catalog.exclusiveSolo]) { fake, mirror in
            let rows = stroke(mirror, from: 1, to: 3)
            fake.stop()

            #expect(await eventually { !mirror.isLive })
            #expect(mirror.soloStroke == nil)
            #expect(!mirror.endSoloStroke())
            #expect(mirror.soloLook(rows[row(2, in: rows)]) != .pending)
        }
    }

    /// Clear during a stroke (a second thumb on the bar) wins: the stroke ends and the desk's cleared solos show.
    @Test func clearEndsAHeldStroke() async throws {
        try await withLiveDesk { fake, mirror in
            stroke(mirror, from: 1, to: 3)
            #expect(await eventually { soloed(fake, 1...3) })

            mirror.clearSolo()

            #expect(mirror.soloStroke == nil)
            #expect(await eventually { mirror.soloedCount == 0 })
        }
    }

    /// The overview went away mid-stroke: the switches it held show the desk's values again.
    @Test func abandoningReleasesTheHolds() async throws {
        try await withLiveDesk { fake, mirror in
            let tom2 = StripID(.input, 5)
            stroke(mirror, from: 1, to: 1)

            mirror.abandonSoloStroke()
            fake.deskChange(tom2.solo, .int(1))

            #expect(mirror.soloStroke == nil)
            #expect(await eventually { mirror.cell(tom2.solo).argument == .int(1) })
        }
    }
}

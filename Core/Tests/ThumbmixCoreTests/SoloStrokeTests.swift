import Testing

@testable import ThumbmixCore

/// A hold on a name, then a drag down or up the names, as Photos selects (2026-10-19): every row passed gets the
/// held row's new state, and rows the finger leaves go back.
struct SoloStrokeTests {
    private let fourOff: [Bool?] = [false, false, false, false]

    private func stroke(_ snapshot: [Bool?], start: Int = 0, soloed: Int = 0, exclusive: Bool = false) -> SoloStroke {
        SoloStroke(snapshot: snapshot, start: start, soloedBefore: soloed, gatesExclusive: exclusive)
    }

    @Test func holdingSolosTheRow() {
        let held = stroke(fourOff)
        #expect(held.target)
        #expect(held.writes == [0: true])
        #expect(held.shown(0) == true)
        #expect(held.shown(1) == false)
    }

    @Test func draggingDownSolosEachRowOnce() {
        var drag = stroke(Array(repeating: false, count: 7))
        var ticked: [Int] = []
        for row in 1...6 { ticked += drag.move(to: row) }
        #expect(ticked == [1, 2, 3, 4, 5, 6])
        #expect(drag.move(to: 6) == [])
        #expect(drag.writes == Dictionary(uniqueKeysWithValues: (0...6).map { ($0, true) }))
    }

    @Test func startingOnASoloedRowUnsolos() {
        var drag = stroke([true, true, true, true], start: 3)
        #expect(!drag.target)
        #expect(drag.move(to: 1) == [2, 1])
        #expect(drag.shown(0) == true)
        #expect(drag.shown(1) == false)
    }

    @Test func draggingBackRestoresTheSnapshot() {
        var drag = stroke([false, false, true, false, false])
        _ = drag.move(to: 4)
        #expect(drag.move(to: 2) == [4, 3])
        #expect(drag.shown(3) == false)
        #expect(drag.shown(2) == true)
    }

    /// The safety rule: a row the desk never told us about is neither soloed nor ticked.
    @Test func unreadRowsAreSkipped() {
        var drag = stroke([false, nil, false])
        #expect(drag.move(to: 2) == [2])
        #expect(drag.shown(1) == nil)
        #expect(drag.writes == [0: true, 2: true])
    }

    /// Exclusive solo would drop each solo for the next: the second and later rows wait for the engineer's answer.
    @Test func exclusiveHoldsTheSecondRowBack() {
        var drag = stroke(fourOff, exclusive: true)
        _ = drag.move(to: 3)
        #expect(drag.writes == [0: true])
        #expect(drag.pending == [1, 2, 3])
    }

    /// A solo already on the desk, in this list or another group, counts as the first.
    @Test func exclusiveCountsSolosAlreadyOn() {
        let held = stroke(fourOff, soloed: 1, exclusive: true)
        #expect(held.writes == [:])
        #expect(held.pending == [0])
    }

    @Test func turnOffWritesThePending() {
        var drag = stroke(fourOff, exclusive: true)
        _ = drag.move(to: 3)
        #expect(drag.resolve(turnOff: true) == [1: true, 2: true, 3: true])
        #expect(drag.pending == [])
        #expect(drag.writes.count == 4)
    }

    @Test func keepDropsThePending() {
        var drag = stroke(fourOff, exclusive: true)
        _ = drag.move(to: 3)
        #expect(drag.resolve(turnOff: false) == [:])
        #expect(drag.pending == [])
        #expect(drag.shown(2) == false)
        #expect(drag.shown(0) == true)
    }

    @Test func unsoloIsNeverGated() {
        var drag = stroke([true, true, true, false], exclusive: true)
        _ = drag.move(to: 2)
        #expect(drag.pending == [])
        #expect(drag.writes == [0: false, 1: false, 2: false])
    }

    /// Contact lost mid-stroke: nothing held back is ever written.
    @Test func cancelDropsPending() {
        var drag = stroke(fourOff, exclusive: true)
        _ = drag.move(to: 2)
        drag.cancel()
        #expect(drag.pending == [])
        #expect(drag.shown(2) == false)
    }
}

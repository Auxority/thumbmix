import Foundation

/// A hold on an overview name, then a drag up or down the names, as Photos selects (2026-10-19): every row from the
/// held one to the finger gets the held row's new state; rows the finger leaves go back to how they were.
/// Pure, so the rows are tested with explicit indexes; `ConsoleMirror+SoloStroke` writes the desk.
public struct SoloStroke: Sendable {
    /// Soloing when the held row wasn't soloed, unsoloing when it was.
    public let target: Bool
    /// The row under the finger.
    public private(set) var reach: Int
    /// Each row's solo at touch-down; nil = never read, which the stroke skips (the safety rule).
    private let snapshot: [Bool?]
    private let start: Int
    /// Solos already on the desk at touch-down: under Exclusive solo a new one would drop them.
    private let soloedBefore: Int
    private var gatesExclusive: Bool
    /// Rows the engineer chose not to solo (Keep), or that were held back when contact was lost.
    private var dropped: Set<Int> = []

    /// `otherSoloed` = soloed rows outside `snapshot` (other groups). `gatesExclusive` = the desk's Exclusive solo is
    /// on and the engineer hasn't answered Keep: a second solo waits for the question.
    public init(snapshot: [Bool?], start: Int, otherSoloed: Int, gatesExclusive: Bool) {
        self.snapshot = snapshot
        self.start = start
        self.gatesExclusive = gatesExclusive
        target = snapshot[start] != true
        reach = start
        soloedBefore = otherSoloed + snapshot.filter { $0 == true }.count
    }

    /// Rows the stroke changes, in the order the finger reached them.
    private var run: [Int] {
        let order = reach >= start ? Array(start...reach) : Array((reach...start).reversed())
        return order.filter { snapshot[$0] != nil && snapshot[$0] != target && !dropped.contains($0) }
    }

    /// Rows held back for the Exclusive solo question: every new solo past the first one the desk would keep.
    public var pending: [Int] {
        guard gatesExclusive, target else { return [] }
        return Array(run.dropFirst(max(0, 1 - soloedBefore)))
    }

    /// What the desk should hold now for the rows the stroke changes.
    public var writes: [Int: Bool] {
        let waiting = Set(pending)
        return Dictionary(uniqueKeysWithValues: run.filter { !waiting.contains($0) }.map { ($0, target) })
    }

    public func shown(_ row: Int) -> Bool? {
        run.contains(row) ? target : snapshot[row]
    }

    /// Moves the finger to `row`; returns the rows whose state changed (one tick each), nearest the old spot first.
    public mutating func move(to row: Int) -> [Int] {
        let rows = snapshot.indices
        let before = rows.map(shown)
        let old = reach
        reach = min(max(row, 0), snapshot.count - 1)
        return rows.filter { before[$0] != shown($0) }.sorted { abs($0 - old) < abs($1 - old) }
    }

    /// The engineer's answer to the Exclusive solo question, after the finger lifted: Turn off writes the rows held
    /// back; Keep leaves them as they were.
    public mutating func resolve(turnOff: Bool) -> [Int: Bool] {
        let held = pending
        guard turnOff else {
            dropped.formUnion(held)
            return [:]
        }
        gatesExclusive = false
        return Dictionary(uniqueKeysWithValues: held.map { ($0, target) })
    }

    /// Contact lost: nothing held back is ever written.
    public mutating func cancel() {
        dropped.formUnion(pending)
    }
}

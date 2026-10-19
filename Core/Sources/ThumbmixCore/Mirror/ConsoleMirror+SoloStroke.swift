import Foundation

/// How a row's name shows its solo: `pending` = passed by a stroke but held back for the Exclusive solo question.
public enum SoloLook: Sendable {
    case off, soloed, pending, unread
}

/// The rows a stroke runs over, as the overview listed them at touch-down, and the stroke's maths.
public struct ActiveSoloStroke: Sendable {
    let rows: [OverviewItem]
    var stroke: SoloStroke
}

/// Writes a `SoloStroke` to the desk (2026-10-19). The finger owns every solo switch of the listed rows from hold to
/// lift (`EditHolds`), so a push meanwhile doesn't fight it; then they're read back and the desk wins.
extension ConsoleMirror {
    /// Starts a stroke on `rows[start]`; returns the rows to tick. Nothing while not live or that row is unread.
    public func beginSoloStroke(_ rows: [OverviewItem], at start: Int) -> [Int] {
        guard isLive, soloStroke == nil, rows.indices.contains(start) else { return [] }
        let snapshot = rows.map(isSoloed)
        guard snapshot[start] != nil else { return [] }
        let stroke = SoloStroke(
            snapshot: snapshot, start: start, otherSoloed: soloedCount - snapshot.filter { $0 == true }.count,
            gatesExclusive: isExclusiveSolo && !keepsExclusiveSolo)
        for address in soloAddresses(rows) { beginEdit(address) }
        soloStroke = ActiveSoloStroke(rows: rows, stroke: stroke)
        apply(stroke.writes, to: rows)
        return [start]
    }

    /// Moves the finger to `row`; writes what changed and returns the rows to tick.
    public func moveSoloStroke(to row: Int) -> [Int] {
        guard isLive, var active = soloStroke else { return [] }
        let ticked = active.stroke.move(to: row)
        soloStroke = active
        let held = Set(active.stroke.pending)
        for row in ticked where !held.contains(row) {
            if let on = active.stroke.shown(row) { setSolo(active.rows[row], on) }
        }
        return ticked
    }

    /// The finger lifted. True when rows wait for the Exclusive solo question; the stroke stays until it's answered.
    public func endSoloStroke() -> Bool {
        guard var active = soloStroke else { return false }
        if !isLive { active.stroke.cancel() }
        guard active.stroke.pending.isEmpty else {
            soloStroke = active
            return true
        }
        finish(active)
        return false
    }

    /// Turn off writes Exclusive solo off ahead of the held rows; Keep leaves them, and isn't asked again.
    public func answerExclusiveSolo(turnOff: Bool) {
        guard var active = soloStroke else { return }
        if turnOff {
            turnOffExclusiveSolo()
            // Sends leave in one batch in no set order: Exclusive must reach the desk before the solos it would drop.
            sendPending()
        } else {
            keepsExclusiveSolo = true
        }
        if !isLive { active.stroke.cancel() }
        apply(active.stroke.resolve(turnOff: turnOff && isLive), to: active.rows)
        finish(active)
    }

    public func soloLook(_ item: OverviewItem) -> SoloLook {
        if let active = soloStroke, let row = active.rows.firstIndex(of: item), active.stroke.pending.contains(row) {
            return .pending
        }
        switch isSoloed(item) {
        case nil: return .unread
        case true?: return .soloed
        case false?: return .off
        }
    }

    private func apply(_ writes: [Int: Bool], to rows: [OverviewItem]) {
        for (row, on) in writes { setSolo(rows[row], on) }
    }

    private func finish(_ active: ActiveSoloStroke) {
        for address in soloAddresses(active.rows) { endEdit(address) }
        soloStroke = nil
    }

    private func soloAddresses(_ rows: [OverviewItem]) -> [String] {
        rows.flatMap { isLinked($0.held) ? $0.held.oddSide.pairSides : [$0.held] }.map(\.solo)
    }

    private func sendPending() {
        for (address, argument) in pendingSends { link.send(OSCMessage(address, [argument])) }
        pendingSends.removeAll()
    }
}

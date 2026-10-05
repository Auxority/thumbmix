/// Which controls the user's finger owns, and when to re-read them from the console.
/// Pure and clock-free, so the timing is tested with explicit instants.
struct EditHolds {
    let hold: Duration
    private var editing: Set<String> = []
    private var heldUntil: [String: ContinuousClock.Instant] = [:]
    private var rereadAt: [String: ContinuousClock.Instant] = [:]

    init(hold: Duration) {
        self.hold = hold
    }

    mutating func begin(_ address: String) {
        editing.insert(address)
    }

    /// Pushes ignored during the gesture are gone, so the value is read back once the hold ends.
    mutating func end(_ address: String, now: ContinuousClock.Instant) {
        editing.remove(address)
        heldUntil[address] = now + hold
        rereadAt[address] = now + hold
    }

    /// A set outside a gesture (nudge, toggle, double-tap) holds briefly against its own echo.
    mutating func edited(_ address: String, now: ContinuousClock.Instant) {
        heldUntil[address] = max(heldUntil[address] ?? now, now + hold)
    }

    func isHeld(_ address: String, now: ContinuousClock.Instant) -> Bool {
        if editing.contains(address) { return true }
        guard let until = heldUntil[address] else { return false }
        return until > now
    }

    mutating func takeDueRereads(now: ContinuousClock.Instant) -> [String] {
        let due = rereadAt.filter { $0.value <= now }.map(\.key)
        for address in due { rereadAt[address] = nil }
        return due
    }

    /// After a resync the console is the truth; only a finger still on a control keeps priority.
    mutating func clearTimedHolds() {
        heldUntil.removeAll()
    }
}

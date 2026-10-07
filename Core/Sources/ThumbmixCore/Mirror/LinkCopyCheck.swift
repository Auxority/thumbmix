/// Whether the desk copies the app's edit of a linked pair to the partner, as it does for its own controls.
/// Unconfirmed on a real M32, so the app checks: it writes one side, re-reads the partner, and hears from here
/// when the partner didn't follow (the mirror decides what that means). Pure, so it is tested without a desk.
struct LinkCopyCheck {
    /// Only an answer this soon after the re-read is judged: a later message may be a change made on the desk,
    /// and taking that for "didn't follow" would write the old value over the engineer's move.
    static let answerWindow: Duration = .seconds(1)

    /// Cleared once fader, mute or a send didn't follow: from then on the app writes both sides itself.
    var deskCopies = true
    private var expected: [String: OSCArgument] = [:]
    private var awaiting: [String: (value: OSCArgument, until: ContinuousClock.Instant)] = [:]

    /// The partner should end up at `value`; its re-read is scheduled by the caller.
    mutating func expect(_ address: String, _ value: OSCArgument) {
        expected[address] = value
        awaiting[address] = nil
    }

    /// Only the answer to the re-read counts: pushes during a drag carry older values.
    mutating func rereadSent(_ address: String, now: ContinuousClock.Instant) {
        if let value = expected.removeValue(forKey: address) { awaiting[address] = (value, now + Self.answerWindow) }
    }

    /// The value the partner should have had when it didn't follow; nil when it did, nothing was awaited, or the
    /// answer came too late to be the re-read's.
    mutating func received(_ address: String, _ value: OSCArgument, now: ContinuousClock.Instant) -> OSCArgument? {
        guard let wanted = awaiting.removeValue(forKey: address), now <= wanted.until,
            !value.isClose(to: wanted.value)
        else { return nil }
        return wanted.value
    }

    /// After a lost connection the resync is the truth: nothing from before it is judged.
    mutating func forget() {
        expected.removeAll()
        awaiting.removeAll()
    }
}

extension OSCArgument {
    /// The desk stores floats in steps (a fader has 1024), so its copy may differ from what was sent by a hair.
    func isClose(to other: OSCArgument) -> Bool {
        guard case .float(let a) = self, case .float(let b) = other else { return self == other }
        return abs(a - b) < 0.002
    }
}

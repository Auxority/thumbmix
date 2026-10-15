/// Whether the desk copies the app's edit of a linked pair to the partner, as it does for its own controls.
/// Unconfirmed on a real M32, so the app checks: it writes one side, re-reads the partner, and hears from here
/// when the partner didn't follow (the mirror decides what that means). Pure, so it is tested without a desk.
struct LinkCopyCheck {
    enum Verdict: Equatable {
        /// Nothing to judge: the partner followed, nothing was awaited, or the answer came too late.
        case none
        /// A first wrong answer may be stale: re-read once more before deciding.
        case askAgain
        /// The partner didn't follow; the value it should have had.
        case leftBehind(OSCArgument)
    }

    /// Only an answer this soon after the re-read is judged: a later message may be a change made on the desk,
    /// and taking that for "didn't follow" would write the old value over the engineer's move.
    static let answerWindow: Duration = .seconds(1)

    /// Cleared once fader, mute or a send didn't follow: from then on the app writes both sides itself.
    var deskCopies = true
    private var expected: [String: OSCArgument] = [:]
    private var awaiting: [String: (value: OSCArgument, until: ContinuousClock.Instant)] = [:]
    /// Partners whose re-read was answered wrong once and are being asked again.
    private var doubted: Set<String> = []

    /// The partner should end up at `value`; its re-read is scheduled by the caller.
    mutating func expect(_ address: String, _ value: OSCArgument) {
        expected[address] = value
        awaiting[address] = nil
        doubted.remove(address)
    }

    /// Only the answer to the re-read counts: pushes during a drag carry older values.
    mutating func rereadSent(_ address: String, now: ContinuousClock.Instant) {
        if let value = expected.removeValue(forKey: address) { awaiting[address] = (value, now + Self.answerWindow) }
    }

    /// A question asked just before the edit is answered with the old value, and that answer can be handled after
    /// the re-read went out (seen on CI's busy main actor). So a wrong answer is asked again once: the second
    /// re-read goes out after every earlier question was answered, and only its wrong answer means left behind.
    /// `arrival` is when the datagram came in, not when the main actor got to it: on a busy main actor (CI's parallel
    /// suite) an answer on time was handled 2 s after the re-read and dropped as late, so the partner was never repaired.
    mutating func received(_ address: String, _ value: OSCArgument, arrivedAt arrival: ContinuousClock.Instant)
        -> Verdict
    {
        guard let wanted = awaiting.removeValue(forKey: address), arrival <= wanted.until else { return .none }
        if value.isClose(to: wanted.value) {
            doubted.remove(address)
            return .none
        }
        if doubted.remove(address) != nil { return .leftBehind(wanted.value) }
        doubted.insert(address)
        expected[address] = wanted.value
        return .askAgain
    }

    /// After a lost connection the resync is the truth: nothing from before it is judged.
    mutating func forget() {
        expected.removeAll()
        awaiting.removeAll()
        doubted.removeAll()
    }
}

extension OSCArgument {
    /// The desk stores floats in steps (a fader has 1024), so its copy may differ from what was sent by a hair.
    func isClose(to other: OSCArgument) -> Bool {
        guard case .float(let a) = self, case .float(let b) = other else { return self == other }
        return abs(a - b) < 0.002
    }
}

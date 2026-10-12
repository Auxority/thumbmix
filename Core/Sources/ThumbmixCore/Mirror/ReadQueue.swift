/// The reads after going live (`ConsoleMirror+Reads`): an opened tab's values first, then the background fill. Paced
/// like `InitialSync`: a few requests in flight, re-asking for replies UDP lost.
@MainActor
final class ReadQueue {
    private let window: Int
    private let timeout: Duration
    private let maxTries: Int
    private var pending: [String] = []
    private var queued: Set<String> = []
    private var inFlight: [String: (sentAt: ContinuousClock.Instant, tries: Int)] = [:]
    private(set) var missing: [String] = []

    init(window: Int = 8, timeout: Duration = .milliseconds(300), maxTries: Int = 10) {
        self.window = window
        self.timeout = timeout
        self.maxTries = maxTries
    }

    /// Urgent addresses (an opened tab) go to the front, taking along any already waiting in the fill.
    func add(_ addresses: [String], urgent: Bool) {
        let new = addresses.filter { inFlight[$0] == nil && (urgent || !queued.contains($0)) }
        guard !new.isEmpty else { return }
        if urgent {
            let moving = Set(new)
            pending = new + pending.filter { !moving.contains($0) }
        } else {
            pending += new
        }
        queued.formUnion(new)
    }

    /// False for a reply this queue didn't ask for.
    func received(_ address: String) -> Bool {
        inFlight.removeValue(forKey: address) != nil
    }

    /// The addresses to (re)request now.
    func due(now: ContinuousClock.Instant) -> [String] {
        let retries = expired(now: now)
        let count = min(window - inFlight.count, pending.count)
        guard count > 0 else { return retries }
        let next = Array(pending.prefix(count))
        pending.removeFirst(count)
        queued.subtract(next)
        for address in next { inFlight[address] = (now, 1) }
        return retries + next
    }

    private func expired(now: ContinuousClock.Instant) -> [String] {
        var requests: [String] = []
        for (address, entry) in inFlight where now - entry.sentAt > timeout {
            if entry.tries >= maxTries {
                inFlight[address] = nil
                missing.append(address)
            } else {
                inFlight[address] = (now, entry.tries + 1)
                requests.append(address)
            }
        }
        return requests
    }
}

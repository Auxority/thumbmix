/// Every read of the mirror: the overview on connect, then an opened tab's values first and the background fill
/// (`ConsoleMirror+Reads`). A few requests in flight, re-asking for replies UDP lost; the author's own dump tools pace
/// requests the same way to avoid overrunning Wi-Fi (doc p.6). 8 stays: on the M32 (2026-10-20, m32-probe section 12)
/// the overview took 1.20 s at 8 with none lost, 0.44 s at 32 but with 6 of 769 replies lost.
@MainActor
final class ReadQueue {
    private let window: Int
    private let timeout: Duration
    private let maxTries: Int
    private var pending: [String] = []
    private var queued: Set<String> = []
    private var inFlight: [String: (sentAt: ContinuousClock.Instant, tries: Int)] = [:]
    private(set) var missing: [String] = []
    private(set) var answered = 0

    /// 10 tries x 300 ms rides out a ~3 s Wi-Fi drop; anything longer makes the link lost and restarts the sync.
    init(window: Int = 8, timeout: Duration = .milliseconds(300), maxTries: Int = 10) {
        self.window = window
        self.timeout = timeout
        self.maxTries = maxTries
    }

    /// Urgent addresses (an opened tab) go to the front, taking along any already waiting in the fill.
    func add(_ addresses: [String], urgent: Bool) {
        var seen = Set<String>()
        let new = addresses.filter { inFlight[$0] == nil && (urgent || !queued.contains($0)) && seen.insert($0).inserted }
        guard !new.isEmpty else { return }
        if urgent {
            let moving = Set(new)
            pending = new + pending.filter { !moving.contains($0) }
        } else {
            pending += new
        }
        queued.formUnion(new)
    }

    /// Nothing waiting, nothing in flight: every address was answered or given up on.
    var isIdle: Bool { pending.isEmpty && inFlight.isEmpty }

    /// False for a reply this queue didn't ask for.
    func received(_ address: String) -> Bool {
        guard inFlight.removeValue(forKey: address) != nil else { return false }
        answered += 1
        return true
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

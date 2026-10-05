/// Reads every address with a few requests in flight, re-asking for replies UDP lost.
/// The author's own dump tools pace requests the same way to avoid overrunning Wi-Fi (doc p.6).
@MainActor
final class InitialSync {
    private let addresses: [String]
    private let window: Int
    private let timeout: Duration
    private let maxTries: Int
    private var next = 0
    private var inFlight: [String: (sentAt: ContinuousClock.Instant, tries: Int)] = [:]
    private var answered = 0
    private(set) var missing: [String] = []

    /// 10 tries x 300 ms rides out a ~3 s Wi-Fi drop; anything longer makes the link lost and restarts the sync.
    init(addresses: [String], window: Int = 8, timeout: Duration = .milliseconds(300), maxTries: Int = 10) {
        self.addresses = addresses
        self.window = window
        self.timeout = timeout
        self.maxTries = maxTries
    }

    var isDone: Bool { next == addresses.count && inFlight.isEmpty }
    var progress: Double { addresses.isEmpty ? 1 : Double(answered) / Double(addresses.count) }

    func received(_ address: String) {
        guard inFlight.removeValue(forKey: address) != nil else { return }
        answered += 1
    }

    /// The addresses to (re)request now.
    func due(now: ContinuousClock.Instant) -> [String] {
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
        while inFlight.count < window, next < addresses.count {
            inFlight[addresses[next]] = (now, 1)
            requests.append(addresses[next])
            next += 1
        }
        return requests
    }
}

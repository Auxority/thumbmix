import Foundation
import ThumbmixCore

/// Section 12. How long connect's overview read takes on this desk and network: at the app's 8 requests in flight,
/// and at 32 (worth raising? The doc warns of routers dropping reply bursts, p.6). Gets only.
@MainActor
func probeReadTiming() async {
    let overview = Catalog.overviewAddresses()
    print("\n== 12. Connect speed: reading the overview (\(overview.count) values), as the app does on connect")
    for window in [8, 32] {
        var timer = ReadTimer(addresses: overview, window: window)
        let seconds = await timer.run()
        print("\(window) in flight: " + String(format: "%.2f s", seconds) + ", \(timer.unanswered) unanswered")
    }
    print("RESULT: the app reads this before going live, 8 at a time. Much faster at 32 with 0 unanswered = raise it.")
}

/// Keeps `window` gets in flight; an answer frees a slot, and one unanswered after 300 ms counts as lost (no
/// retries, so losses show).
@MainActor
private struct ReadTimer {
    let addresses: [String]
    let window: Int
    private(set) var unanswered = 0
    private var next = 0
    private var inFlight: [String: ContinuousClock.Instant] = [:]
    private var seen = 0

    init(addresses: [String], window: Int) {
        self.addresses = addresses
        self.window = window
    }

    mutating func run() async -> Double {
        recorder.clear()
        let start = ContinuousClock.now
        while next < addresses.count || !inFlight.isEmpty {
            takeReplies()
            dropExpired(now: .now)
            sendMore(now: .now)
            try? await Task.sleep(for: .milliseconds(1))
        }
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    }

    private mutating func takeReplies() {
        for message in recorder.messages.dropFirst(seen) { inFlight[message.address] = nil }
        seen = recorder.messages.count
    }

    private mutating func dropExpired(now: ContinuousClock.Instant) {
        for (address, sentAt) in inFlight where now - sentAt > .milliseconds(300) {
            inFlight[address] = nil
            unanswered += 1
        }
    }

    private mutating func sendMore(now: ContinuousClock.Instant) {
        while inFlight.count < window, next < addresses.count {
            transport.send(OSCMessage(addresses[next]))
            inFlight[addresses[next]] = now
            next += 1
        }
    }
}

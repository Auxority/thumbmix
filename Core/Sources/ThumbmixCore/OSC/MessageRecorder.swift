/// Keeps every message from a stream so callers can wait for one by polling.
/// Racing a timeout against the stream would cancel its consumer, and that terminates an AsyncStream.
@MainActor
public final class MessageRecorder {
    /// Each with the transport's arrival time: m32-probe times meter changes from them.
    public private(set) var arrivals: [Arrival] = []
    public var messages: [OSCMessage] { arrivals.map(\.message) }
    private let limit = 5_000

    public init(_ stream: AsyncStream<Arrival>) {
        Task { [weak self] in
            for await arrival in stream { self?.record(arrival) }
        }
    }

    public func last(address: String) -> OSCMessage? {
        arrivals.last { $0.message.address == address }?.message
    }

    public func wait(for address: String, timeout: Duration = .seconds(2)) async -> OSCMessage? {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let message = last(address: address) { return message }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return last(address: address)
    }

    public func clear() { arrivals.removeAll() }

    private func record(_ arrival: Arrival) {
        arrivals.append(arrival)
        if arrivals.count > limit { arrivals.removeFirst(arrivals.count - limit) }
    }
}

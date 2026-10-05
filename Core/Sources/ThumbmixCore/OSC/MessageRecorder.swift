/// Keeps every message from a stream so callers can wait for one by polling.
/// Racing a timeout against the stream would cancel its consumer, and that terminates an AsyncStream.
@MainActor
public final class MessageRecorder {
    public private(set) var messages: [OSCMessage] = []
    private var task: Task<Void, Never>?
    private let limit = 5_000

    public init(_ stream: AsyncStream<OSCMessage>) {
        task = Task { [weak self] in
            for await message in stream { self?.record(message) }
        }
    }

    public func last(address: String) -> OSCMessage? {
        messages.last { $0.address == address }
    }

    public func wait(for address: String, timeout: Duration = .seconds(2)) async -> OSCMessage? {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let message = last(address: address) { return message }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return last(address: address)
    }

    public func clear() { messages.removeAll() }

    public func stop() { task?.cancel() }

    private func record(_ message: OSCMessage) {
        messages.append(message)
        if messages.count > limit { messages.removeFirst(messages.count - limit) }
    }
}

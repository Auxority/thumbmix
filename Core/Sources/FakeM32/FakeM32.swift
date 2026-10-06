import Foundation
import Network
import ThumbmixCore

/// Stands in for an M32 in tests, the simulator and the app's Offline mode: answers gets, applies sets, pushes changes to
/// `/xremote` clients and streams synthetic meters. All mutable state is touched only on `queue`.
public final class FakeM32: @unchecked Sendable {
    /// Only touched on `queue`, which Network.framework's callbacks also run on.
    private final class Client: @unchecked Sendable {
        let connection: NWConnection
        var remoteUntil = Date.distantPast
        var meterBanksUntil: [String: Date] = [:]
        init(_ connection: NWConnection) { self.connection = connection }
    }

    private let queue = DispatchQueue(label: "fake-m32")
    private let listener: NWListener
    private let started = Date()
    private var state: [String: OSCArgument]
    private var clients: [ObjectIdentifier: Client] = [:]
    private var meterTimer: DispatchSourceTimer?
    private var startContinuation: CheckedContinuation<UInt16, Error>?
    private var modelStorage: String
    private var isSilent = false
    private var isIgnoringXremote = false
    private var getsToDrop = 0
    private var sets: [OSCMessage] = []

    public init(
        port: UInt16 = 0, model: String = "M32", state: [String: OSCArgument] = DemoState.values()
    ) throws {
        let parameters = NWParameters.udp
        parameters.requiredLocalEndpoint = .hostPort(
            host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port) ?? .any)
        parameters.allowLocalEndpointReuse = true
        listener = try NWListener(using: parameters)
        self.state = state
        modelStorage = model
    }

    /// Starts listening and returns the bound UDP port.
    public func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                startContinuation = continuation
                listener.stateUpdateHandler = { [self] in handleListener($0) }
                listener.newConnectionHandler = { [self] in accept($0) }
                listener.start(queue: queue)
                startMeterTimer()
            }
        }
    }

    public func stop() {
        queue.sync {
            meterTimer?.cancel()
            for client in clients.values { client.connection.cancel() }
            clients = [:]
            listener.cancel()
        }
    }

    // MARK: Test controls

    public var model: String {
        get { queue.sync { modelStorage } }
        set { queue.sync { modelStorage = newValue } }
    }

    /// While silent the fake ignores everything and sends nothing, like an unplugged console.
    public var silent: Bool {
        get { queue.sync { isSilent } }
        set { queue.sync { isSilent = newValue } }
    }

    /// Like a console that already has its maximum of `/xremote` clients: no pushes for this client.
    public var ignoresXremote: Bool {
        get { queue.sync { isIgnoringXremote } }
        set { queue.sync { isIgnoringXremote = newValue } }
    }

    public func dropNextGets(_ count: Int) { queue.sync { getsToDrop = count } }

    public func value(at address: String) -> OSCArgument? { queue.sync { state[address] } }

    public var receivedSets: [OSCMessage] { queue.sync { sets } }

    /// Someone moved a control on the desk.
    public func deskChange(_ address: String, _ value: OSCArgument) {
        queue.sync {
            state[address] = value
            push(OSCMessage(address, [value]), except: nil)
        }
    }

    // MARK: Protocol

    private func handleListener(_ listenerState: NWListener.State) {
        switch listenerState {
        case .ready:
            startContinuation?.resume(returning: listener.port?.rawValue ?? 0)
            startContinuation = nil
        case .failed(let error):
            startContinuation?.resume(throwing: error)
            startContinuation = nil
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        let client = Client(connection)
        clients[ObjectIdentifier(connection)] = client
        connection.start(queue: queue)
        receive(from: client)
    }

    private func receive(from client: Client) {
        client.connection.receiveMessage { [self] data, _, _, error in
            if let data, let message = try? OSCCodec.decode(data) { handle(message, from: client) }
            if error == nil { receive(from: client) }
        }
    }

    private func handle(_ message: OSCMessage, from client: Client) {
        guard !isSilent else { return }
        switch message.address {
        case "/xinfo":
            send(
                OSCMessage(
                    "/xinfo",
                    [.string("127.0.0.1"), .string("Fake M32"), .string(modelStorage), .string("4.06")]),
                to: client)
        case "/info":
            send(
                OSCMessage(
                    "/info",
                    [.string("V2.07"), .string("osc-server"), .string(modelStorage), .string("4.06")]),
                to: client)
        case "/xremote":
            guard !isIgnoringXremote else { return }
            client.remoteUntil = Date().addingTimeInterval(10)
        case "/meters":
            guard case .string(var bank)? = message.arguments.first else { return }
            if !bank.hasPrefix("/") { bank = "/" + bank }
            client.meterBanksUntil[bank] = Date().addingTimeInterval(10)
        default:
            if message.arguments.isEmpty {
                answerGet(message.address, client)
            } else {
                applySet(message, from: client)
            }
        }
    }

    private func answerGet(_ address: String, _ client: Client) {
        if getsToDrop > 0 {
            getsToDrop -= 1
            return
        }
        // A real console stays silent for addresses it doesn't know.
        guard let value = state[address] else { return }
        send(OSCMessage(address, [value]), to: client)
    }

    private func applySet(_ message: OSCMessage, from sender: Client) {
        state[message.address] = message.arguments[0]
        sets.append(message)
        push(message, except: sender)
    }

    private func push(_ message: OSCMessage, except sender: Client?) {
        let now = Date()
        for client in clients.values where client !== sender && client.remoteUntil > now {
            send(message, to: client)
        }
    }

    private func startMeterTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(50))
        timer.setEventHandler { [self] in sendMeters() }
        timer.resume()
        meterTimer = timer
    }

    private func sendMeters() {
        guard !isSilent else { return }
        let now = Date()
        let time = now.timeIntervalSince(started)
        for client in clients.values {
            for (bank, until) in client.meterBanksUntil where until > now {
                send(OSCMessage(bank, [.blob(FakeState.meterBlob(bank: bank, time: time))]), to: client)
            }
        }
    }

    private func send(_ message: OSCMessage, to client: Client) {
        client.connection.send(content: OSCCodec.encode(message), completion: .idempotent)
    }
}

import Foundation
import Network
import os

/// A small HTTP/1.1 server on a TCP `NWListener`: one request per connection, answered and closed. Everything it
/// touches (the listener's callbacks and `connections`) runs on `queue`.
final class HTTPServer: @unchecked Sendable {
    typealias Handler = @Sendable (HTTPRequest) async -> HTTPResponse

    /// A phone serving a laptop needs a handful; this keeps a flood of sockets from exhausting the app.
    static let maxConnections = 16
    /// A request that hasn't fully arrived by then is dropped (a client that sends one byte a minute).
    static let requestTimeout: DispatchTimeInterval = .seconds(10)
    private static let chunk = 16 * 1024

    private let queue = DispatchQueue(label: "thumbmix.remote")
    private let listener: NWListener
    private let maxBody: Int
    private let handler: Handler
    private let log = Logger(subsystem: "thumbmix", category: "mcp")
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var startContinuation: CheckedContinuation<UInt16, Error>?

    /// "0.0.0.0" listens on every interface, IPv6 too; any other address binds just that one.
    init(host: String, port: UInt16, maxBody: Int, handler: @escaping Handler) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let endpointPort = NWEndpoint.Port(rawValue: port) ?? .any
        if host == "0.0.0.0" {
            listener = try NWListener(using: parameters, on: endpointPort)
        } else {
            parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host(host), port: endpointPort)
            listener = try NWListener(using: parameters)
        }
        self.maxBody = maxBody
        self.handler = handler
    }

    /// Starts listening and returns the bound port; throws when the port can't be taken.
    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                startContinuation = continuation
                listener.stateUpdateHandler = { [self] in listenerChanged($0) }
                listener.newConnectionHandler = { [self] in accept($0) }
                listener.start(queue: queue)
            }
        }
    }

    func stop() {
        queue.sync {
            listener.cancel()
            for connection in connections.values { connection.cancel() }
        }
    }

    private func listenerChanged(_ state: NWListener.State) {
        switch state {
        case .ready:
            startContinuation?.resume(returning: listener.port?.rawValue ?? 0)
            startContinuation = nil
        case .failed(let error):
            log.error("remote server failed: \(error.localizedDescription, privacy: .public)")
            startContinuation?.resume(throwing: error)
            startContinuation = nil
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        guard connections.count < Self.maxConnections else {
            log.warning("too many connections; one refused")
            connection.cancel()
            return
        }
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        connection.stateUpdateHandler = { [self] state in
            switch state {
            case .failed: connection.cancel()
            case .cancelled: connections[key] = nil
            default: break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + Self.requestTimeout) { connection.cancel() }
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.chunk) { [self] data, _, isComplete, error in
            let buffer = buffer + (data ?? Data())
            switch HTTPRequestParser.parse(buffer, maxBody: maxBody) {
            case .needMore:
                if error != nil || isComplete { connection.cancel() } else { receive(on: connection, buffer: buffer) }
            case .request(let request):
                answer(request, on: connection)
            case .refuse(let status, let reason):
                finish(connection, HTTPResponse(status: status, json: ["error": .string(reason)]))
            }
        }
    }

    private func answer(_ request: HTTPRequest, on connection: NWConnection) {
        Task { [handler] in
            let response = await handler(request)
            queue.async { [self] in finish(connection, response) }
        }
    }

    private func finish(_ connection: NWConnection, _ response: HTTPResponse) {
        connection.send(
            content: response.serialized(), contentContext: .finalMessage, isComplete: true,
            completion: .contentProcessed { _ in connection.cancel() })
    }
}

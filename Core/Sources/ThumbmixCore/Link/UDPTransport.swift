import Foundation
import Network
import os

/// A UDP socket to one console. Network.framework calls back on `queue`; decoded messages come out of `messages`.
public final class UDPTransport: @unchecked Sendable {
    public let messages: AsyncStream<OSCMessage>
    private let continuation: AsyncStream<OSCMessage>.Continuation
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "thumbmix.udp")
    private let log = Logger(subsystem: "thumbmix", category: "udp")

    public init(host: String, port: UInt16) {
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 10023,
            using: .udp
        )
        (messages, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1024))
    }

    public func start() {
        connection.stateUpdateHandler = { [log] state in
            log.info("udp state \(String(describing: state), privacy: .public)")
        }
        connection.start(queue: queue)
        receiveNext()
    }

    public func send(_ message: OSCMessage) {
        connection.send(content: OSCCodec.encode(message), completion: .contentProcessed { [log] error in
            if let error { log.error("send failed: \(error.localizedDescription, privacy: .public)") }
        })
    }

    public func cancel() {
        connection.cancel()
        continuation.finish()
    }

    private func receiveNext() {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data {
                do { continuation.yield(try OSCCodec.decode(data)) }
                catch { log.debug("dropped malformed packet: \(String(describing: error), privacy: .public)") }
            }
            if let error {
                log.error("receive stopped: \(error.localizedDescription, privacy: .public)")
                return
            }
            receiveNext()
        }
    }
}

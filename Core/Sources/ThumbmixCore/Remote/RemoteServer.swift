import Foundation
import os

/// Where the remote API listens and what it accepts.
public struct RemoteConfiguration: Sendable {
    /// All interfaces by default: the phone is reached from a laptop on the same network.
    public var bindAddress = "0.0.0.0"
    public var port: UInt16 = 8032
    /// Browsers send `Origin`; programs don't. A request carrying one that is not listed here is refused (DNS rebinding).
    public var allowedOrigins: Set<String> = []
    public var maxBodyBytes = 64 * 1024
    /// How long a tool waits for the desk to answer the reads it asked for.
    public var readTimeout: Duration = .seconds(3)
    public var serverVersion = "dev"

    public init() {}
}

/// Lets an AI client (Claude Code, say, on a laptop on the same network) read and set the console through the app:
/// MCP at `POST /mcp` and a plain JSON API at `/api/tools`, both running the same tools on the app's `ConsoleMirror`, so
/// every write passes the mirror's safety rule. There is no login: the network is the boundary, as it already is for
/// anyone who can send OSC to the desk. Only `Origin` is checked, against browsers.
@MainActor
public final class RemoteServer {
    private let mirror: ConsoleMirror
    private let configuration: RemoteConfiguration
    private var server: HTTPServer?
    private let log = Logger(subsystem: "thumbmix", category: "mcp")

    public init(mirror: ConsoleMirror, configuration: RemoteConfiguration = RemoteConfiguration()) {
        self.mirror = mirror
        self.configuration = configuration
    }

    /// Starts listening and returns the port; throws when it can't be taken (another server on it).
    public func start() async throws -> UInt16 {
        stop()
        let tools = DeskTools(mirror: mirror, readTimeout: configuration.readTimeout).table
        let router = RemoteRouter(tools: tools, configuration: configuration)
        let server = try HTTPServer(
            host: configuration.bindAddress, port: configuration.port, maxBody: configuration.maxBodyBytes,
            handler: { await router.respond(to: $0) })
        let port = try await server.start()
        self.server = server
        log.info("remote server listening on port \(port)")
        return port
    }

    public func stop() {
        guard let server else { return }
        server.stop()
        self.server = nil
        log.info("remote server stopped")
    }
}

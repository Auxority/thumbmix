import Foundation
import os

public typealias RemoteHandler = @Sendable (RemoteRequest) async -> RemoteResponse

/// Where the HTTP side listens and what the tools accept.
public struct RemoteConfiguration: Sendable {
    /// Loopback by default; `thumbmix-mcp --bind` opens it to the network.
    public var bindAddress = "127.0.0.1"
    public var port: UInt16 = 8032
    /// Browsers send `Origin`; programs don't. An HTTP request carrying one that is not listed here is refused (DNS rebinding).
    public var allowedOrigins: Set<String> = []
    public var maxBodyBytes = 64 * 1024
    /// How long a tool waits for the desk to answer the reads it asked for.
    public var readTimeout: Duration = .seconds(3)

    public init() {}
}

/// Lets an AI client (Claude Code, say) read and set the console: MCP over stdio, and optionally MCP at `POST /mcp` plus a
/// plain JSON API at `/api/tools` over HTTP, all running the same tools on one `ConsoleMirror`, so every write passes the
/// mirror's safety rule. There is no login: the network is the boundary, as it already is for anyone who can send OSC to
/// the desk. HTTP only checks `Origin`, against browsers.
@MainActor
public final class RemoteServer {
    let tools: DeskTools
    let configuration: RemoteConfiguration
    private var http: HTTPServer?
    let log = Logger(subsystem: "thumbmix", category: "mcp")

    /// The desk connection as the tools see it now; it changes when `keepConnected` replaces a mirror that gave up.
    public var status: MirrorStatus { tools.mirror.status }

    public init(mirror: ConsoleMirror, configuration: RemoteConfiguration = RemoteConfiguration()) {
        tools = DeskTools(mirror: mirror, readTimeout: configuration.readTimeout)
        self.configuration = configuration
    }

    /// Starts the HTTP side and returns its port; throws when it can't be taken (another server on it). `mcp` answers
    /// `POST /mcp` after the Origin check; without it HTTP serves only the JSON API.
    public func start(mcp: RemoteHandler? = nil) async throws -> UInt16 {
        stop()
        let router = RemoteRouter(tools: tools.table, configuration: configuration, mcpHandler: mcp)
        let server = try HTTPServer(
            host: configuration.bindAddress, port: configuration.port, maxBody: configuration.maxBodyBytes,
            handler: { await router.respond(to: $0) })
        let port = try await server.start()
        http = server
        log.info("remote server listening on port \(port)")
        return port
    }

    public func stop() {
        guard let http else { return }
        http.stop()
        self.http = nil
        log.info("remote server stopped")
    }
}

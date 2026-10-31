import Foundation
import MCP
import ThumbmixCore

#if canImport(System)
    import System
#else
    @preconcurrency import SystemPackage
#endif

/// The MCP protocol is the official Swift SDK's (https://github.com/modelcontextprotocol/swift-sdk, which speaks the
/// 2025-11-25 revision of the spec and its predecessors; the stateless 2026-07-28 revision is not in it yet). This
/// only registers `RemoteServer`'s tools with it, so lifecycle, version negotiation and framing are the SDK's, and
/// the tools, their argument checks and the desk's safety rules stay in ThumbmixCore.
public enum MCPBridge {
    /// A server that answers `tools/list` and `tools/call` from `remote`. One SDK server serves one transport, so each
    /// transport gets its own, over the same tools.
    public static func makeServer(for remote: RemoteServer, version: String) async -> Server {
        let server = Server(
            name: "thumbmix", version: version, title: "Thumbmix", instructions: RemoteServer.instructions,
            capabilities: .init(tools: .init(listChanged: false)))
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: try await remote.toolInfos.map(tool(from:)))
        }
        await server.withMethodHandler(CallTool.self) { parameters in
            let arguments = try JSONEncoder().encode(parameters.arguments ?? [:])
            guard let result = await remote.callTool(parameters.name, arguments: arguments) else {
                throw MCPError.invalidParams("Unknown tool: \(parameters.name.prefix(64))")
            }
            let structured = result.structured.flatMap { try? JSONDecoder().decode(Value.self, from: $0) }
            return .init(
                content: [.text(text: result.text, annotations: nil, _meta: nil)], structuredContent: structured, isError: result.isError)
        }
        return server
    }

    private static func tool(from info: RemoteToolInfo) throws -> Tool {
        Tool(
            name: info.name, description: info.description,
            inputSchema: try JSONDecoder().decode(Value.self, from: info.inputSchema),
            annotations: .init(
                readOnlyHint: info.isReadOnly, destructiveHint: false, idempotentHint: info.isReadOnly, openWorldHint: false))
    }

    /// MCP over stdio: newline-delimited JSON-RPC on `input` and `output`, nothing else on `output`. Returns when `input`
    /// ends, which is how the client says goodbye.
    public static func serveStdio(
        _ remote: RemoteServer, version: String, input: FileHandle = .standardInput, output: FileHandle = .standardOutput
    ) async throws {
        let server = await makeServer(for: remote, version: version)
        let transport = StdioTransport(
            input: FileDescriptor(rawValue: input.fileDescriptor), output: FileDescriptor(rawValue: output.fileDescriptor))
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
        await server.stop()
    }

    /// MCP at `POST /mcp` for `RemoteServer.start(mcp:)`, through the SDK's stateless HTTP transport (single JSON
    /// replies, no session, no SSE). The router has already refused any `Origin` not allowed, so the SDK's own origin
    /// check, which only knows localhost, is left out.
    public static func httpHandler(for remote: RemoteServer, version: String) async throws -> RemoteHandler {
        let transport = StatelessHTTPServerTransport(
            validationPipeline: StandardValidationPipeline(validators: [
                AcceptHeaderValidator(mode: .jsonOnly), ContentTypeValidator(), ProtocolVersionValidator(),
            ]))
        let server = await makeServer(for: remote, version: version)
        try await server.start(transport: transport)
        return { request in
            let reply = await transport.handleRequest(
                MCP.HTTPRequest(method: request.method, headers: request.headers, body: request.body, path: request.path))
            return RemoteResponse(status: reply.statusCode, headers: reply.headers, body: reply.bodyData ?? Data())
        }
    }
}

import Foundation
import Testing
import ThumbmixMCP

@testable import ThumbmixCore

/// MCP at `POST /mcp`: the SDK's stateless HTTP transport behind our own server, which keeps the Origin check and the
/// limits. The protocol itself is the SDK's, so this only proves the two are wired together.
@MainActor
struct RemoteMCPHTTPTests {
    private func withMCP(
        _ mirror: ConsoleMirror, body: (RemoteClient) async throws -> Void
    ) async throws {
        let remote = RemoteServer(mirror: mirror)
        let handler = try await MCPBridge.httpHandler(for: remote, version: "test")
        try await withRemote(mirror, mcp: handler, body: body)
    }

    @Test func aClientCanInitializeAndCallToolsOverHTTP() async throws {
        try await withLiveDesk { _, mirror in
            try await withMCP(mirror) { client in
                let initialize = try await client.rpc(
                    "initialize", ["protocolVersion": "2025-11-25", "capabilities": [:], "clientInfo": ["name": "t", "version": "1"]])
                #expect(initialize.status == 200)
                #expect(initialize.result?["protocolVersion"] == "2025-11-25")
                #expect(initialize.headers["mcp-session-id"] == nil, "stateless: no session")

                let notified = try await client.post("/mcp", ["jsonrpc": "2.0", "method": "notifications/initialized"])
                #expect(notified.status == 202)

                let list = try await client.rpc("tools/list")
                guard case .array(let tools)? = list.result?["tools"] else {
                    Issue.record("no tools in \(String(describing: list.json))")
                    return
                }
                #expect(tools.count == 6)

                let call = try await client.rpc("tools/call", ["name": "get_strip", "arguments": ["strip": "Kick"]])
                #expect(call.result?["structuredContent"]?["id"] == "ch/01")

                let get = try await client.get("/mcp")
                #expect(get.status == 405)
            }
        }
    }

    @Test func theOriginCheckAndTheLimitsStillApply() async throws {
        try await withMCP(idleMirror()) { client in
            let browser = try await client.rpc("ping", headers: ["Origin": "http://evil.example"])
            #expect(browser.status == 403)
            let text = try await client.post(
                "/mcp", ["jsonrpc": "2.0", "id": 1, "method": "ping"], headers: ["Content-Type": "text/plain"])
            #expect(text.status == 415)
        }
    }
}

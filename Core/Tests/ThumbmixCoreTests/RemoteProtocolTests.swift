import Foundation
import Testing

@testable import ThumbmixCore

/// The MCP and JSON endpoints as a client sees them, over a real local HTTP connection, on a desk that is not live:
/// protocol shape, refusals and the one tool table. Tool behaviour against a desk is in `RemoteDeskTests`.
@MainActor
struct RemoteProtocolTests {
    private let toolNames = ["list_strips", "get_strip", "set_fader", "set_mute", "set_eq_band", "set_comp"]

    @Test func initializeNegotiatesTheVersionAndAdvertisesTools() async throws {
        try await withRemote(idleMirror()) { client in
            let params: JSON = ["protocolVersion": "2025-06-18", "capabilities": [:], "clientInfo": ["name": "t", "version": "1"]]
            let reply = try await client.rpc("initialize", params)

            #expect(reply.status == 200)
            #expect(reply.headers["content-type"]?.hasPrefix("application/json") == true)
            #expect(reply.json?["id"] == 1)
            #expect(reply.result?["protocolVersion"] == "2025-06-18")
            #expect(reply.result?["capabilities"]?["tools"] != nil)
            #expect(reply.result?["serverInfo"]?["name"] == "thumbmix")
            #expect(reply.result?["instructions"]?.string?.isEmpty == false)
            #expect(reply.headers["mcp-session-id"] == nil)
        }
    }

    @Test func anUnknownVersionGetsTheServersLatest() async throws {
        try await withRemote(idleMirror()) { client in
            let reply = try await client.rpc("initialize", ["protocolVersion": "1999-01-01"])

            #expect(reply.result?["protocolVersion"] == "2025-11-25")
        }
    }

    @Test func initializedAndOtherNotificationsAreAcceptedWithoutABody() async throws {
        try await withRemote(idleMirror()) { client in
            for method in ["notifications/initialized", "notifications/cancelled", "notifications/whatever"] {
                let reply = try await client.post("/mcp", ["jsonrpc": "2.0", "method": .string(method)])
                #expect(reply.status == 202, "\(method)")
                #expect(reply.json == nil)
            }
        }
    }

    @Test func pingAnswersAnEmptyResult() async throws {
        try await withRemote(idleMirror()) { client in
            let r1 = try await client.rpc("ping")
            #expect(r1.result == [:])
        }
    }

    @Test func toolsListHoldsEverySchemaAndMatchesTheJSONAPI() async throws {
        try await withRemote(idleMirror()) { client in
            let mcp = try await client.rpc("tools/list")
            let api = try await client.get("/api/tools")

            guard case .array(let tools)? = mcp.result?["tools"] else {
                Issue.record("no tools in \(String(describing: mcp.json))")
                return
            }
            #expect(tools.compactMap { $0["name"]?.string } == toolNames)
            for tool in tools {
                #expect(tool["description"]?.string?.isEmpty == false)
                #expect(tool["inputSchema"]?["type"] == "object")
                #expect(tool["inputSchema"]?["additionalProperties"] == false)
            }
            #expect(api.status == 200)
            #expect(api.json?["tools"] == mcp.result?["tools"])
            let eq = tools.first { $0["name"] == "set_eq_band" }
            #expect(eq?["inputSchema"]?["properties"]?["gain_db"]?["minimum"] == -15)
            #expect(eq?["inputSchema"]?["required"] == ["strip", "band"])
        }
    }

    @Test func aToolCallOnADeskThatIsNotLiveIsAnErrorResultSayingSo() async throws {
        try await withRemote(idleMirror()) { client in
            let result = try await client.call("set_fader", ["strip": "ch/01", "db": 0])

            #expect(result.isError)
            #expect(result.text.contains("connecting"))
        }
    }

    @Test func protocolErrorsKeepTheirJSONRPCCodes() async throws {
        try await withRemote(idleMirror()) { client in
            let badJSON = try await client.post("/mcp", nil, raw: "{nope")
            #expect(badJSON.status == 400)
            #expect(badJSON.errorCode == -32700)
            #expect(badJSON.json?["id"] == .null)

            let batch = try await client.post("/mcp", nil, raw: "[{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\"}]")
            #expect(batch.status == 400)
            #expect(batch.errorCode == -32600)

            let noMethod = try await client.post("/mcp", ["jsonrpc": "2.0", "id": 4])
            #expect(noMethod.errorCode == -32600)

            let badID = try await client.post("/mcp", ["jsonrpc": "2.0", "id": true, "method": "ping"])
            #expect(badID.errorCode == -32600)

            let unknownMethod = try await client.rpc("resources/list")
            #expect(unknownMethod.errorCode == -32601)
            #expect(unknownMethod.json?["id"] == 1)

            let unknownTool = try await client.rpc("tools/call", ["name": "launch_missiles"])
            #expect(unknownTool.errorCode == -32602)
            #expect(unknownTool.json?["error"]?["message"]?.string?.contains("launch_missiles") == true)

            let noName = try await client.rpc("tools/call", ["arguments": [:]])
            #expect(noName.errorCode == -32602)

            let badArguments = try await client.rpc("tools/call", ["name": "list_strips", "arguments": [1, 2]])
            #expect(badArguments.errorCode == -32602)
        }
    }

    @Test func badArgumentsAreAnErrorResultTheModelCanReadAndFix() async throws {
        try await withRemote(idleMirror()) { client in
            let outOfRange = try await client.call("set_eq_band", ["strip": "ch/01", "band": 1, "gain_db": 40])
            #expect(outOfRange.isError)
            #expect(outOfRange.text.contains("'gain_db' must be between -15 and 15"))

            let stray = try await client.call("set_fader", ["strip": "ch/01", "db": 0, "volume": 3])
            #expect(stray.isError)
            #expect(stray.text.contains("Unknown argument 'volume'"))

            let wrongType = try await client.call("set_mute", ["strip": "ch/01", "muted": "yes"])
            #expect(wrongType.isError)
            #expect(wrongType.text.contains("'muted' must be true or false"))
        }
    }

    @Test func theGETStreamIsNotOfferedAndOtherVerbsAreRefused() async throws {
        try await withRemote(idleMirror()) { client in
            let get = try await client.get("/mcp")
            #expect(get.status == 405)
            #expect(get.headers["allow"] == "POST")
            let r2 = try await client.get("/mcp", method: "DELETE")
            #expect(r2.status == 405)
            let r3 = try await client.get("/api/tools", method: "DELETE")
            #expect(r3.status == 405)
            let r4 = try await client.get("/elsewhere")
            #expect(r4.status == 404)
        }
    }

    @Test func aBodyThatIsNotJSONByContentTypeIsRefused() async throws {
        try await withRemote(idleMirror()) { client in
            let reply = try await client.post(
                "/mcp", ["jsonrpc": "2.0", "id": 1, "method": "ping"], headers: ["Content-Type": "text/plain"])

            #expect(reply.status == 415)
        }
    }

    @Test func aBodyOverTheLimitIsRefused() async throws {
        try await withRemote(idleMirror(), maxBodyBytes: 100) { client in
            let reply = try await client.post("/mcp", nil, raw: String(repeating: " ", count: 300))

            #expect(reply.status == 413)
        }
    }

    // MARK: Origin and versions

    @Test func aRequestWithAnOriginIsRefusedOnEveryEndpoint() async throws {
        try await withRemote(idleMirror()) { client in
            let origin = ["Origin": "http://evil.example"]
            let mcp = try await client.rpc("ping", headers: origin)
            #expect(mcp.status == 403)
            #expect(mcp.result == nil)
            let r5 = try await client.get("/api/tools", headers: origin)
            #expect(r5.status == 403)
            let r6 = try await client.post("/api/tools/list_strips", [:], headers: origin)
            #expect(r6.status == 403)
            let r7 = try await client.rpc("ping", headers: ["Origin": "null"])
            #expect(r7.status == 403)
        }
    }

    @Test func aRequestWithoutAnOriginOrWithAnAllowedOneIsServed() async throws {
        try await withRemote(idleMirror(), allowedOrigins: ["http://localhost:6274"]) { client in
            let r8 = try await client.rpc("ping")
            #expect(r8.status == 200)
            let r9 = try await client.rpc("ping", headers: ["Origin": "http://localhost:6274"])
            #expect(r9.status == 200)
            let r10 = try await client.rpc("ping", headers: ["Origin": "http://localhost:6275"])
            #expect(r10.status == 403)
        }
    }

    @Test func anUnsupportedProtocolVersionHeaderIsRefused() async throws {
        try await withRemote(idleMirror()) { client in
            let bad = try await client.rpc("ping", headers: ["MCP-Protocol-Version": "1999-01-01"])
            #expect(bad.status == 400)
            #expect(bad.errorCode == -32022)
            #expect(bad.json?["error"]?["data"]?["requested"] == "1999-01-01")

            for version in ["2025-03-26", "2025-06-18", "2025-11-25"] {
                let r11 = try await client.rpc("ping", headers: ["MCP-Protocol-Version": version])
                #expect(r11.status == 200)
            }
        }
    }

    // MARK: The stateless revision (2026-07-28)

    private let modern = "2026-07-28"

    private func meta(_ version: String? = nil) -> JSON {
        [
            "_meta": [
                "io.modelcontextprotocol/protocolVersion": .string(version ?? modern), "io.modelcontextprotocol/clientCapabilities": [:],
            ]
        ]
    }

    @Test func aStatelessClientNeedsNoInitialize() async throws {
        try await withRemote(idleMirror()) { client in
            let headers = ["MCP-Protocol-Version": modern, "Mcp-Method": "tools/list"]
            let list = try await client.rpc("tools/list", meta(), headers: headers)
            #expect(list.status == 200)
            #expect(list.result?["resultType"] == "complete")
            #expect(list.result?["tools"] != nil)

            let discover = try await client.rpc(
                "server/discover", meta(), headers: ["MCP-Protocol-Version": modern, "Mcp-Method": "server/discover"])
            #expect(discover.result?["supportedVersions"] == ["2026-07-28", "2025-11-25", "2025-06-18", "2025-03-26"])
            #expect(discover.result?["capabilities"]?["tools"] != nil)
        }
    }

    @Test func aStatelessRequestMustMirrorItsMetadataInHeaders() async throws {
        try await withRemote(idleMirror()) { client in
            let noMethod = try await client.rpc("tools/list", meta(), headers: ["MCP-Protocol-Version": modern])
            #expect(noMethod.status == 400)
            #expect(noMethod.errorCode == -32020)

            let wrongMethod = try await client.rpc(
                "tools/list", meta(), headers: ["MCP-Protocol-Version": modern, "Mcp-Method": "ping"])
            #expect(wrongMethod.errorCode == -32020)

            let noMeta = try await client.rpc("tools/list", [:], headers: ["MCP-Protocol-Version": modern, "Mcp-Method": "tools/list"])
            #expect(noMeta.status == 400)
            #expect(noMeta.errorCode == -32602)

            let otherVersion = try await client.rpc(
                "tools/list", meta("2025-11-25"), headers: ["MCP-Protocol-Version": modern, "Mcp-Method": "tools/list"])
            #expect(otherVersion.errorCode == -32020)

            let wrongName = try await client.rpc(
                "tools/call", ["name": "list_strips", "_meta": meta()["_meta"]!],
                headers: ["MCP-Protocol-Version": modern, "Mcp-Method": "tools/call", "Mcp-Name": "get_strip"])
            #expect(wrongName.errorCode == -32020)
        }
    }

    // MARK: The JSON API

    @Test func theJSONAPIRunsTheSameToolsWithTheSameResultShape() async throws {
        try await withRemote(idleMirror()) { client in
            let viaAPI = try await client.post("/api/tools/set_fader", ["strip": "ch/01", "db": 0])
            let viaMCP = try await client.call("set_fader", ["strip": "ch/01", "db": 0])

            #expect(viaAPI.status == 503)
            #expect(viaAPI.json == viaMCP)
            #expect(viaAPI.json?.isError == true)
        }
    }

    @Test func theJSONAPIRefusesWhatItCannotRun() async throws {
        try await withRemote(idleMirror()) { client in
            let r12 = try await client.post("/api/tools/launch_missiles", [:])
            #expect(r12.status == 404)
            let r13 = try await client.post("/api/tools/list_strips", nil, raw: "{nope")
            #expect(r13.status == 400)
            let r14 = try await client.post("/api/tools/list_strips", nil, raw: "[]")
            #expect(r14.status == 400)

            let outOfRange = try await client.post("/api/tools/set_comp", ["strip": "ch/01", "threshold_db": 5])
            #expect(outOfRange.status == 422)
            #expect(outOfRange.json?.text.contains("'threshold_db' must be between -60 and 0") == true)

            let noBody = try await client.post("/api/tools/list_strips", nil, raw: "")
            #expect(noBody.json?.isError == true, "an empty body is no arguments; the desk is not live")
            #expect(noBody.status == 503)
        }
    }
}

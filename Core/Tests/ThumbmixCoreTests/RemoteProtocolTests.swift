import Foundation
import Testing

@testable import ThumbmixCore

/// The JSON API and the HTTP front door as a client sees them, over a real local HTTP connection, on a desk that is not
/// live: the tool list, refusals, limits, and who may ask. MCP itself is the SDK's (`RemoteMCPTests`); tool behaviour
/// against a desk is in `RemoteDeskTests`.
@MainActor
struct RemoteProtocolTests {
    private let toolNames = ["list_strips", "get_strip", "set_fader", "set_mute", "set_eq_band", "set_comp"]

    /// Stands in for the MCP SDK behind `/mcp`: the router's own checks are what these tests look at.
    private let echo: RemoteHandler = { _ in RemoteResponse(status: 200, body: Data("{}".utf8)) }

    @Test func theToolListHoldsEverySchema() async throws {
        try await withRemote(idleMirror()) { client in
            let api = try await client.get("/api/tools")

            #expect(api.status == 200)
            guard case .array(let tools)? = api.json?["tools"] else {
                Issue.record("no tools in \(String(describing: api.json))")
                return
            }
            #expect(tools.compactMap { $0["name"]?.string } == toolNames)
            for tool in tools {
                #expect(tool["description"]?.string?.isEmpty == false)
                #expect(tool["inputSchema"]?["type"] == "object")
                #expect(tool["inputSchema"]?["additionalProperties"] == false)
            }
            let eq = tools.first { $0["name"] == "set_eq_band" }
            #expect(eq?["inputSchema"]?["properties"]?["gain_db"]?["minimum"] == -15)
            #expect(eq?["inputSchema"]?["required"] == ["strip", "band"])
            #expect(eq?["annotations"]?["readOnlyHint"] == false)
        }
    }

    @Test func aToolCallOnADeskThatIsNotLiveIsAnErrorResultSayingSo() async throws {
        try await withRemote(idleMirror()) { client in
            let reply = try await client.post("/api/tools/set_fader", ["strip": "ch/01", "db": 0])

            #expect(reply.status == 503)
            #expect(reply.json?.isError == true)
            #expect(reply.json?.text.contains("connecting") == true)
        }
    }

    @Test func badArgumentsAreAnErrorResultTheModelCanReadAndFix() async throws {
        try await withRemote(idleMirror()) { client in
            let outOfRange = try await client.post("/api/tools/set_eq_band", ["strip": "ch/01", "band": 1, "gain_db": 40])
            #expect(outOfRange.status == 422)
            #expect(outOfRange.json?.text.contains("'gain_db' must be between -15 and 15") == true)

            let stray = try await client.post("/api/tools/set_fader", ["strip": "ch/01", "db": 0, "volume": 3])
            #expect(stray.json?.text.contains("Unknown argument 'volume'") == true)

            let wrongType = try await client.post("/api/tools/set_mute", ["strip": "ch/01", "muted": "yes"])
            #expect(wrongType.json?.text.contains("'muted' must be true or false") == true)

            let noRatio = try await client.post("/api/tools/set_comp", ["strip": "ch/01", "threshold_db": 5])
            #expect(noRatio.json?.text.contains("'threshold_db' must be between -60 and 0") == true)
        }
    }

    @Test func theJSONAPIRefusesWhatItCannotRun() async throws {
        try await withRemote(idleMirror()) { client in
            let unknown = try await client.post("/api/tools/launch_missiles", [:])
            #expect(unknown.status == 404)
            let badJSON = try await client.post("/api/tools/list_strips", nil, raw: "{nope")
            #expect(badJSON.status == 400)
            let array = try await client.post("/api/tools/list_strips", nil, raw: "[]")
            #expect(array.status == 400)
            let noBody = try await client.post("/api/tools/list_strips", nil, raw: "")
            #expect(noBody.status == 503, "an empty body is no arguments; the desk is not live")
            let get = try await client.get("/api/tools/list_strips")
            #expect(get.status == 405)
            let verb = try await client.get("/api/tools", method: "DELETE")
            #expect(verb.status == 405)
            let elsewhere = try await client.get("/elsewhere")
            #expect(elsewhere.status == 404)
        }
    }

    @Test func aBodyThatIsNotJSONByContentTypeIsRefused() async throws {
        try await withRemote(idleMirror()) { client in
            let reply = try await client.post("/api/tools/list_strips", [:], headers: ["Content-Type": "text/plain"])

            #expect(reply.status == 415)
        }
    }

    @Test func aBodyOverTheLimitIsRefused() async throws {
        try await withRemote(idleMirror(), maxBodyBytes: 100) { client in
            let reply = try await client.post("/api/tools/list_strips", nil, raw: String(repeating: " ", count: 300))

            #expect(reply.status == 413)
        }
    }

    // MARK: /mcp

    @Test func withoutAnMCPHandlerHTTPServesOnlyTheJSONAPI() async throws {
        try await withRemote(idleMirror()) { client in
            let reply = try await client.rpc("ping")

            #expect(reply.status == 404)
        }
    }

    @Test func theMCPEndpointTakesOnlyJSONPostsAndNoStream() async throws {
        try await withRemote(idleMirror(), mcp: echo) { client in
            let ok = try await client.rpc("ping")
            #expect(ok.status == 200)

            let get = try await client.get("/mcp")
            #expect(get.status == 405)
            #expect(get.headers["allow"] == "POST")
            let delete = try await client.get("/mcp", method: "DELETE")
            #expect(delete.status == 405)
            let text = try await client.post(
                "/mcp", ["jsonrpc": "2.0", "id": 1, "method": "ping"], headers: ["Content-Type": "text/plain"])
            #expect(text.status == 415)
        }
    }

    // MARK: Origin

    @Test func aRequestWithAnOriginIsRefusedOnEveryEndpoint() async throws {
        try await withRemote(idleMirror(), mcp: echo) { client in
            let origin = ["Origin": "http://evil.example"]
            let mcp = try await client.rpc("ping", headers: origin)
            #expect(mcp.status == 403)
            #expect(mcp.errorCode == -32600)
            let list = try await client.get("/api/tools", headers: origin)
            #expect(list.status == 403)
            let call = try await client.post("/api/tools/list_strips", [:], headers: origin)
            #expect(call.status == 403)
            let null = try await client.rpc("ping", headers: ["Origin": "null"])
            #expect(null.status == 403)
        }
    }

    @Test func aRequestWithoutAnOriginOrWithAnAllowedOneIsServed() async throws {
        try await withRemote(idleMirror(), allowedOrigins: ["http://localhost:6274"], mcp: echo) { client in
            let none = try await client.rpc("ping")
            #expect(none.status == 200)
            let allowed = try await client.rpc("ping", headers: ["Origin": "http://localhost:6274"])
            #expect(allowed.status == 200)
            let other = try await client.rpc("ping", headers: ["Origin": "http://localhost:6275"])
            #expect(other.status == 403)
        }
    }
}

import Foundation
import os

/// `POST /mcp`: MCP over Streamable HTTP, the smallest correct subset. Every request is answered with one
/// `application/json` object (no SSE stream: a tool call is a few UDP round trips); notifications get 202. Handles
/// `initialize`, `ping`, `tools/list`, `tools/call`, and for stateless clients `server/discover`. There is no session:
/// every call stands alone, so no `Mcp-Session-Id` is minted.
struct MCPEndpoint: Sendable {
    let tools: ToolTable
    let serverVersion: String
    private static let log = Logger(subsystem: "thumbmix", category: "mcp")

    private static let knownMethods: Set<String> = [
        "initialize", "ping", "tools/list", "tools/call", "server/discover",
    ]

    /// What the model reads first: how to use the tools safely.
    static let instructions = """
        These tools control a Midas M32 mixing console through the Thumbmix app. Values are real units: dB, Hz, ms. \
        Find the strip with list_strips, read it with get_strip, then change it with a set_ tool. For a relative \
        request ("more bass", "more compression") read the current value first and move from it in small steps \
        (about 1-3 dB of EQ gain), unless the user asks for more: a change is audible at once, maybe in a live show. \
        A value that is null was not read from the desk and is unknown. Writes while contact with the desk is lost \
        are refused.
        """

    func respond(to request: HTTPRequest, requestID: Int) async -> HTTPResponse {
        var id: JSON = .null
        do {
            let message = try RPCMessage(parsing: request.body)
            guard let messageID = message.id else {
                Self.log.info("[\(requestID)] mcp notification \(Self.loggable(message.method), privacy: .public) accepted")
                return HTTPResponse(status: 202)
            }
            id = messageID
            let era = try MCPEra(header: request.headers["mcp-protocol-version"])
            if era == .modern && message.method != "initialize" { try Self.validateStateless(message, request) }
            let result = try await dispatch(message, era: era, requestID: requestID)
            Self.log.info("[\(requestID)] mcp \(Self.loggable(message.method), privacy: .public) ok")
            return HTTPResponse(status: 200, json: RPCError.resultBody(id: id, result: era == .modern ? Self.stateless(result) : result))
        } catch let error as RPCError {
            Self.log.info("[\(requestID)] mcp error \(error.code): \(error.message, privacy: .public)")
            return HTTPResponse(status: error.status, json: RPCError.errorBody(id: id, error: error))
        } catch {
            return HTTPResponse(status: 500, json: RPCError.errorBody(id: id, error: RPCError(code: -32603, message: "Internal error")))
        }
    }

    /// A method name comes from the network: only ones this server knows reach the log.
    private static func loggable(_ method: String) -> String { knownMethods.contains(method) ? method : "(unknown method)" }

    private func dispatch(_ message: RPCMessage, era: MCPEra, requestID: Int) async throws -> JSON {
        switch (message.method, era) {
        case ("initialize", .legacy): return try initialize(message.params)
        case ("ping", _): return [:]
        case ("tools/list", _): return ["tools": tools.listJSON]
        case ("tools/call", _): return try await callTool(message.params, requestID: requestID)
        case ("server/discover", .modern): return discover
        default: throw RPCError.methodNotFound(message.method, era: era)
        }
    }

    // MARK: Lifecycle

    private func initialize(_ params: [String: JSON]) throws -> JSON {
        guard let requested = params["protocolVersion"]?.string else {
            throw RPCError.invalidParams("initialize needs a protocolVersion.")
        }
        let version = MCPEra.legacyVersions.contains(requested) ? requested : MCPEra.legacyVersions[0]
        return [
            "protocolVersion": .string(version), "capabilities": capabilities, "serverInfo": serverInfo,
            "instructions": .string(Self.instructions),
        ]
    }

    private var capabilities: JSON { ["tools": ["listChanged": false]] }

    private var serverInfo: JSON { ["name": "thumbmix", "title": "Thumbmix", "version": .string(serverVersion)] }

    private var discover: JSON {
        [
            "supportedVersions": .array(MCPEra.supportedVersions.map(JSON.string)), "capabilities": capabilities,
            "instructions": .string(Self.instructions),
        ]
    }

    /// The stateless revision's results say so, and name the server.
    private static func stateless(_ result: JSON) -> JSON {
        guard case .object(var fields) = result else { return result }
        fields["resultType"] = "complete"
        fields["_meta"] = ["io.modelcontextprotocol/serverInfo": ["name": "thumbmix"]]
        return .object(fields)
    }

    /// The headers must mirror the body (streamable-http, "Server Validation"), and every request carries its version
    /// and capabilities in `_meta`.
    private static func validateStateless(_ message: RPCMessage, _ request: HTTPRequest) throws {
        guard request.headers["mcp-method"] == message.method else {
            throw RPCError.headerMismatch("The Mcp-Method header must be \"\(message.method.prefix(64))\".")
        }
        guard let meta = message.params["_meta"]?.object, let version = meta["io.modelcontextprotocol/protocolVersion"]?.string,
            meta["io.modelcontextprotocol/clientCapabilities"]?.object != nil
        else {
            throw RPCError.invalidParams(
                "_meta needs io.modelcontextprotocol/protocolVersion and io.modelcontextprotocol/clientCapabilities.", status: 400)
        }
        guard version == request.headers["mcp-protocol-version"] else {
            throw RPCError.headerMismatch("The MCP-Protocol-Version header must equal the protocolVersion in _meta.")
        }
        if message.method == "tools/call", request.headers["mcp-name"] != message.params["name"]?.string {
            throw RPCError.headerMismatch("The Mcp-Name header must equal the tool name.")
        }
    }

    // MARK: Tools

    /// An unknown tool or a malformed call is a protocol error; a refusal of the tool itself is a result with
    /// `isError`, which the model reads and corrects.
    private func callTool(_ params: [String: JSON], requestID: Int) async throws -> JSON {
        guard let name = params["name"]?.string else { throw RPCError.invalidParams("tools/call needs a tool name.") }
        guard let tool = tools.tool(named: name) else { throw RPCError.invalidParams("Unknown tool: \(name.prefix(64))") }
        let arguments: [String: JSON]
        switch params["arguments"] {
        case nil, .null?: arguments = [:]
        case .object(let given)?: arguments = given
        default: throw RPCError.invalidParams("arguments must be an object.")
        }
        return await tools.call(tool, arguments: arguments, requestID: requestID).json
    }
}

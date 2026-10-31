import Foundation
import os

/// Which endpoint a request is for, and who may ask. Two front ends share one tool table: `POST /mcp` (MCP over
/// Streamable HTTP) and a plain JSON API (`GET /api/tools`, `POST /api/tools/<name>`).
struct RemoteRouter: Sendable {
    let tools: ToolTable
    let configuration: RemoteConfiguration
    /// Answers `POST /mcp`; nil serves no MCP over HTTP.
    let mcpHandler: RemoteHandler?
    private static let log = Logger(subsystem: "thumbmix", category: "mcp")
    private static let toolPrefix = "/api/tools/"

    /// Logs one line per request under its own number: method, path and outcome. A request's body never reaches the log.
    func respond(to request: RemoteRequest) async -> RemoteResponse {
        let id = RequestIDs.next()
        let response = await route(request, requestID: id)
        Self.log.info("[\(id)] \(request.method, privacy: .public) \(Self.loggable(request.path), privacy: .public) -> \(response.status)")
        return response
    }

    /// The path comes from the network: a long or odd one is cut before it reaches the log.
    private static func loggable(_ path: String) -> String {
        String(path.prefix(80).filter { $0.isASCII && !$0.isNewline })
    }

    private func route(_ request: RemoteRequest, requestID: Int) async -> RemoteResponse {
        let isMCP = request.path == "/mcp"
        // A browser sends Origin, a program doesn't: a page on another site, or a rebound DNS name, is refused.
        if let origin = request.headers["origin"], !configuration.allowedOrigins.contains(origin) {
            Self.log.warning("[\(requestID)] request with an Origin that is not allowed was refused")
            return Self.refusal(403, "Requests from browsers are not accepted.", rpc: isMCP)
        }
        switch request.path {
        case "/mcp":
            return await mcp(request)
        case "/api/tools":
            guard request.method == "GET" else { return Self.notAllowed("GET", rpc: false) }
            return RemoteResponse(status: 200, json: ["tools": tools.listJSON])
        case let path where path.hasPrefix(Self.toolPrefix):
            return await runTool(String(path.dropFirst(Self.toolPrefix.count)), request, requestID: requestID)
        default:
            return Self.refusal(404, "There is nothing at this path. Try POST /mcp or GET /api/tools.", rpc: false)
        }
    }

    /// MCP itself is the SDK's (`ThumbmixMCP`); this only lets in what passed the Origin check, as a POST of JSON. No SSE
    /// stream is offered, so a GET (and anything but a POST) gets 405, as the transport allows.
    private func mcp(_ request: RemoteRequest) async -> RemoteResponse {
        guard let mcpHandler else { return Self.refusal(404, "MCP is not served over HTTP here. Try GET /api/tools.", rpc: false) }
        guard request.method == "POST" else { return Self.notAllowed("POST", rpc: true) }
        guard Self.isJSON(request) else { return Self.refusal(415, "The body must be application/json.", rpc: true) }
        return await mcpHandler(request)
    }

    private func runTool(_ name: String, _ request: RemoteRequest, requestID: Int) async -> RemoteResponse {
        guard request.method == "POST" else { return Self.notAllowed("POST", rpc: false) }
        guard Self.isJSON(request) else { return Self.refusal(415, "The body must be application/json.", rpc: false) }
        guard let tool = tools.tool(named: name.removingPercentEncoding ?? name) else {
            return Self.refusal(404, "Unknown tool. GET /api/tools lists them.", rpc: false)
        }
        let arguments: [String: JSON]
        do {
            arguments = try Self.arguments(of: request.body)
        } catch let error as ToolError {
            return Self.refusal(400, error.message, rpc: false)
        } catch {
            return Self.refusal(400, "The body could not be read.", rpc: false)
        }
        let result = await tools.call(tool, arguments: arguments, requestID: requestID)
        return RemoteResponse(status: result.httpStatus, json: result.json)
    }

    /// An empty body is a call without arguments.
    private static func arguments(of body: Data) throws -> [String: JSON] {
        guard !body.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) else { return [:] }
        guard let json = try? JSON.parse(body) else { throw ToolError.invalid("The body is not valid JSON.") }
        guard case .object(let arguments) = json else { throw ToolError.invalid("The body must be a JSON object of arguments.") }
        return arguments
    }

    /// A body needs `application/json` (a simple cross-site form post can't send it); no body needs no type.
    private static func isJSON(_ request: RemoteRequest) -> Bool {
        guard let type = request.headers["content-type"] else { return request.body.isEmpty }
        return type.lowercased().hasPrefix("application/json")
    }

    private static func notAllowed(_ allowed: String, rpc: Bool) -> RemoteResponse {
        var response = refusal(405, "This path takes \(allowed) only.", rpc: rpc)
        response = RemoteResponse(
            status: response.status, headers: response.headers.merging(["Allow": allowed]) { $1 }, body: response.body)
        return response
    }

    private static func refusal(_ status: Int, _ message: String, rpc: Bool) -> RemoteResponse {
        let body: JSON =
            rpc
            ? ["jsonrpc": "2.0", "id": .null, "error": ["code": -32600, "message": .string(message)]]
            : ["error": .string(message)]
        return RemoteResponse(status: status, json: body)
    }
}

import Foundation

/// A JSON-RPC failure, with the HTTP status Streamable HTTP answers it with.
struct RPCError: Error {
    let code: Int
    let message: String
    var status = 200
    var data: JSON?

    static func parse(_ message: String) -> RPCError { RPCError(code: -32700, message: message, status: 400) }
    static func invalidRequest(_ message: String) -> RPCError { RPCError(code: -32600, message: message, status: 400) }
    static func invalidParams(_ message: String, status: Int = 200) -> RPCError {
        RPCError(code: -32602, message: message, status: status)
    }
    /// The stateless revision answers an unknown method with 404 (streamable-http, "Protocol Version Header").
    static func methodNotFound(_ method: String, era: MCPEra) -> RPCError {
        RPCError(code: -32601, message: "Method not found: \(method.prefix(64))", status: era == .modern ? 404 : 200)
    }
    /// `-32020`: the headers and the body disagree about what the request is.
    static func headerMismatch(_ message: String) -> RPCError { RPCError(code: -32020, message: message, status: 400) }

    static func errorBody(id: JSON, error: RPCError) -> JSON {
        var fields: [String: JSON] = ["code": .number(Double(error.code)), "message": .string(error.message)]
        fields["data"] = error.data
        return ["jsonrpc": "2.0", "id": id, "error": .object(fields)]
    }

    static func resultBody(id: JSON, result: JSON) -> JSON {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }
}

/// Two eras of MCP share this endpoint. `legacy` (2025-03-26 to 2025-11-25) opens with `initialize`; `modern`
/// (2026-07-28) carries its version and capabilities in every request and has no handshake.
enum MCPEra: Equatable {
    case legacy
    case modern

    static let modernVersion = "2026-07-28"
    /// Newest first: a client that asks for another version is answered with the first.
    static let legacyVersions = ["2025-11-25", "2025-06-18", "2025-03-26"]
    static var supportedVersions: [String] { [modernVersion] + legacyVersions }

    /// A request without the header is a client from before 2025-06-18, which didn't send one (assumed 2025-03-26).
    init(header: String?) throws {
        switch header {
        case nil: self = .legacy
        case MCPEra.modernVersion?: self = .modern
        case let version? where MCPEra.legacyVersions.contains(version): self = .legacy
        case let version?:
            var error = RPCError(code: -32022, message: "Unsupported protocol version", status: 400)
            error.data = ["supported": .array(MCPEra.supportedVersions.map(JSON.string)), "requested": .string(String(version.prefix(40)))]
            throw error
        }
    }
}

/// One JSON-RPC message from a client, checked for shape.
struct RPCMessage {
    let method: String
    /// Nil for a notification.
    let id: JSON?
    let params: [String: JSON]

    init(parsing body: Data) throws {
        let json: JSON
        do {
            json = try JSON.parse(body)
        } catch {
            throw RPCError.parse("The body is not valid JSON.")
        }
        guard case .object(let fields) = json else {
            throw RPCError.invalidRequest("The body must be one JSON-RPC message; batches are not supported.")
        }
        guard fields["jsonrpc"] == "2.0", let method = fields["method"]?.string else {
            throw RPCError.invalidRequest("A JSON-RPC 2.0 request needs \"jsonrpc\": \"2.0\" and a \"method\".")
        }
        self.method = method
        id = try Self.id(in: fields)
        switch fields["params"] {
        case nil, .null?: params = [:]
        case .object(let given)?: params = given
        default: throw RPCError.invalidParams("params must be an object.", status: 400)
        }
    }

    /// A string or a whole number, as MCP requires; never null or a flag.
    private static func id(in fields: [String: JSON]) throws -> JSON? {
        guard let id = fields["id"] else { return nil }
        switch id {
        case .string: return id
        case .number(let number) where number == number.rounded(): return id
        default: throw RPCError.invalidRequest("The id must be a string or a whole number.")
        }
    }
}

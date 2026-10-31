import FakeM32
import Foundation
import Testing

@testable import ThumbmixCore

/// A client of the remote server over a real local HTTP connection.
struct RemoteClient {
    let port: UInt16

    struct Reply {
        let status: Int
        let json: JSON?
        let headers: [String: String]
    }

    /// POSTs `body` as JSON, or the raw text when it isn't JSON. `headers` replace the defaults.
    func post(_ path: String, _ body: JSON?, headers: [String: String] = [:], raw: String? = nil) async throws -> Reply {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = raw.map { Data($0.utf8) } ?? body?.serialized()
        return try await send(request)
    }

    func get(_ path: String, headers: [String: String] = [:], method: String = "GET") async throws -> Reply {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        request.httpMethod = method
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        return try await send(request)
    }

    /// A JSON-RPC request; `id` is 1 unless given.
    func rpc(_ method: String, _ params: JSON? = nil, headers: [String: String] = [:]) async throws -> Reply {
        var message: [String: JSON] = ["jsonrpc": "2.0", "id": 1, "method": .string(method)]
        if let params { message["params"] = params }
        return try await post("/mcp", .object(message), headers: headers)
    }

    /// The JSON API's `POST /api/tools/<tool>`, and the result it answers (the shape MCP's `tools/call` has too).
    func call(_ tool: String, _ arguments: JSON = [:]) async throws -> JSON {
        let reply = try await post("/api/tools/\(tool)", arguments)
        return try #require(reply.json)
    }

    private func send(_ request: URLRequest) async throws -> Reply {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        let (data, response) = try await URLSession(configuration: configuration).data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        var headers: [String: String] = [:]
        for (name, value) in http.allHeaderFields { headers["\(name)".lowercased()] = "\(value)" }
        return Reply(status: http.statusCode, json: try? JSON.parse(data), headers: headers)
    }
}

extension RemoteClient.Reply {
    var result: JSON? { json?["result"] }
    var errorCode: Double? { if case .number(let code)? = json?["error"]?["code"] { code } else { nil } }
}

extension JSON {
    var isError: Bool { self["isError"] == true }
    var structured: JSON? { self["structuredContent"] }
    var text: String { self["content"].flatMap { if case .array(let items) = $0 { items.first?["text"]?.string } else { nil } } ?? "" }
}

/// A mirror that never connects: tools see a desk that is not live.
@MainActor
func idleMirror() -> ConsoleMirror {
    ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9, timing: .fast), auditAddresses: [])
}

/// Runs `body` against a remote server on a free local port, and stops it afterwards.
@MainActor
func withRemote(
    _ mirror: ConsoleMirror, maxBodyBytes: Int = 64 * 1024, allowedOrigins: Set<String> = [],
    readTimeout: Duration = .seconds(3), mcp: RemoteHandler? = nil, body: (RemoteClient) async throws -> Void
) async throws {
    var configuration = RemoteConfiguration()
    configuration.bindAddress = "127.0.0.1"
    configuration.port = 0
    configuration.maxBodyBytes = maxBodyBytes
    configuration.allowedOrigins = allowedOrigins
    configuration.readTimeout = readTimeout
    let server = RemoteServer(mirror: mirror, configuration: configuration)
    let port = try await server.start(mcp: mcp)
    defer { server.stop() }
    try await body(RemoteClient(port: port))
}

import FakeM32
import Foundation
import Testing

@testable import ThumbmixCore

@MainActor
func eventually(timeout: Duration = .seconds(8), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return condition()
}

/// A mirror that never connects: tools see a desk that is not live.
@MainActor
func idleMirror() -> ConsoleMirror {
    ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9), auditAddresses: [])
}

/// Runs `body` against a fresh fake desk and a mirror that is live on it, and stops both afterwards. The fake streams
/// no meters: nothing here reads them.
@MainActor
func withLiveDesk(body: (FakeM32, ConsoleMirror) async throws -> Void) async throws {
    let fake = try FakeM32(streamsMeters: false)
    let port = try await fake.start()
    defer { fake.stop() }
    let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port), auditAddresses: [])
    mirror.start()
    defer { mirror.stop() }
    #expect(await eventually(timeout: .seconds(30)) { mirror.isLive }, "the mirror never finished its sync")
    try await body(fake, mirror)
}

/// Runs `body` against `RemoteServer`'s HTTP side on a free local port, with `mcp` behind `/mcp`.
@MainActor
func withRemote(
    _ mirror: ConsoleMirror, mcp: RemoteHandler? = nil, body: (RemoteClient) async throws -> Void
) async throws {
    var configuration = RemoteConfiguration()
    configuration.bindAddress = "127.0.0.1"
    configuration.port = 0
    let server = RemoteServer(mirror: mirror, configuration: configuration)
    let port = try await server.start(mcp: mcp)
    defer { server.stop() }
    try await body(RemoteClient(port: port))
}

/// A client of the HTTP side over a real local connection.
struct RemoteClient {
    let port: UInt16

    struct Reply {
        let status: Int
        let json: JSON?
        let headers: [String: String]

        var result: JSON? { json?["result"] }
    }

    func post(_ path: String, _ body: JSON, headers: [String: String] = [:]) async throws -> Reply {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = body.serialized()
        return try await send(request)
    }

    func get(_ path: String) async throws -> Reply {
        try await send(URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!))
    }

    /// A JSON-RPC request with id 1.
    func rpc(_ method: String, _ params: JSON? = nil, headers: [String: String] = [:]) async throws -> Reply {
        var message: [String: JSON] = ["jsonrpc": "2.0", "id": 1, "method": .string(method)]
        if let params { message["params"] = params }
        return try await post("/mcp", .object(message), headers: headers)
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

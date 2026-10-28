import Foundation

@testable import ThumbmixCore

func presetData(_ name: String) throws -> Data {
    try PresetJSON.encode(.kick.named(name))
}

/// A preset whose gate threshold the desk can't take.
func brokenPresetData(_ name: String) throws -> Data {
    var preset = Preset.kick.named(name)
    preset.values[.gate]?["gate/thr"] = .number(20)
    return try PresetJSON.encode(preset)
}

func indexData(name: String = "Test source", paths: [String]) throws -> Data {
    let object: [String: Any] = [
        "format": "thumbmix-source", "version": 1, "name": name, "presets": paths.map { ["path": $0] },
    ]
    return try JSONSerialization.data(withJSONObject: object)
}

/// `https://<host>/presets/<path>`: each test uses a host of its own, so tests running in parallel never see each
/// other's routes.
func sourceURL(_ host: String, _ path: String = "index.json") -> URL {
    URL(string: "https://\(host)/presets/\(path)")!
}

/// Serves an index and its files at `sourceURL(host)`.
func route(_ host: String, index: Data, files: [String: Data] = [:]) {
    StubRoutes.shared.set(sourceURL(host), .ok(index, contentType: "application/json"))
    for (path, data) in files {
        StubRoutes.shared.set(sourceURL(host, path), .ok(data, contentType: "text/plain; charset=utf-8"))
    }
}

/// Web sources in a folder of their own, every request answered by the stub.
func makeSources(
    in folder: URL, defaults: [URL] = [], deadline: Duration = .seconds(30)
) -> PresetSources {
    PresetSources(folder: folder, defaults: defaults, session: StubRoutes.session(), deadline: deadline)
}

/// Answers every request of a test's session from `StubRoutes`, so no test touches the network.
final class StubProtocol: URLProtocol {
    enum Reply: Sendable {
        case ok(Data, contentType: String)
        case status(Int)
        case redirect(URL)
        case hangs
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let reply = StubRoutes.shared.reply(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        switch reply {
        case .ok(let data, let contentType):
            respond(url, 200, ["Content-Type": contentType], data)
        case .status(let code):
            respond(url, code, [:], Data())
        case .redirect(let target):
            let response = HTTPURLResponse(
                url: url, statusCode: 302, httpVersion: nil, headerFields: ["Location": target.absoluteString])!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            // A session that refuses the redirect keeps this answer; one that follows it has stopped this load.
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case .hangs:
            break
        }
    }

    override func stopLoading() {}

    private func respond(_ url: URL, _ code: Int, _ headers: [String: String], _ data: Data) {
        let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class StubRoutes: @unchecked Sendable {
    static let shared = StubRoutes()
    private let lock = NSLock()
    private var routes: [URL: StubProtocol.Reply] = [:]

    func set(_ url: URL, _ reply: StubProtocol.Reply) {
        lock.withLock { routes[url] = reply }
    }

    func reply(for url: URL) -> StubProtocol.Reply? {
        lock.withLock { routes[url] }
    }

    /// A session whose requests all end at the stub.
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }
}

import Foundation

@testable import ThumbmixCore

/// A fresh folder in the temporary directory, removed by the test's `defer`.
func makeTemporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("thumbmix-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

extension Preset {
    /// `.kick` under another name: the only part of a preset these tests vary.
    func named(_ name: String) -> Preset {
        var copy = self
        copy.name = name
        return copy
    }
}

func presetData(_ name: String) throws -> Data {
    try PresetJSON.encode(Preset.kick.named(name))
}

/// A preset whose gate threshold the desk can't take.
func brokenPresetData(_ name: String) throws -> Data {
    var preset = Preset.kick.named(name)
    preset.gate?.thresholdDb = 20
    return try PresetJSON.encode(preset)
}

func indexData(name: String = "Test source", paths: [String]) throws -> Data {
    let object: [String: Any] = [
        "format": "thumbmix-source", "version": 1, "name": name, "presets": paths.map { ["path": $0] },
    ]
    return try JSONSerialization.data(withJSONObject: object)
}

/// Answers every request of a test's session from `StubRoutes`, so no test touches the network. Each test uses a
/// host of its own, so tests running in parallel never see each other's routes.
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
    private var routes: [String: StubProtocol.Reply] = [:]

    func set(_ url: String, _ reply: StubProtocol.Reply) {
        lock.withLock { routes[url] = reply }
    }

    func reply(for url: URL) -> StubProtocol.Reply? {
        lock.withLock { routes[url.absoluteString] }
    }

    /// A session whose requests all end at the stub.
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }
}

/// A library in folders of its own, removed with the test's `defer`.
struct LibraryFolders {
    let root: URL
    var support: URL { root.appendingPathComponent("support") }
    var own: URL { root.appendingPathComponent("own") }
    var cache: URL { root.appendingPathComponent("cache") }

    init() throws { root = try makeTemporaryFolder() }
}

@MainActor
func makeLibrary(_ folders: LibraryFolders, defaultSource: Bool = false) -> PresetLibrary {
    PresetLibrary(
        supportDirectory: folders.support, ownFolder: folders.own, cacheDirectory: folders.cache,
        session: StubRoutes.session(), includesDefaultSource: defaultSource)
}

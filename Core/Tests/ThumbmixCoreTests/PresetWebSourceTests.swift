import Foundation
import Testing

@testable import ThumbmixCore

/// Web sources: an index on an HTTPS address and the presets it lists, against a stubbed session.
struct PresetWebSourceTests {
    private func reader(cache: URL? = nil, session: URLSession = StubRoutes.session()) throws -> SourceReader {
        SourceReader(session: session, cacheDirectory: try cache ?? makeTemporaryFolder())
    }

    private func url(_ host: String, _ path: String = "index.json") -> URL {
        URL(string: "https://\(host)/presets/\(path)")!
    }

    private func route(_ host: String, index: Data, files: [String: Data]) {
        StubRoutes.shared.set(url(host).absoluteString, .ok(index, contentType: "application/json"))
        for (path, data) in files {
            StubRoutes.shared.set(url(host, path).absoluteString, .ok(data, contentType: "text/plain; charset=utf-8"))
        }
    }

    @Test func anIndexListsPresetsRelativeToItself() async throws {
        let host = "list.test"
        route(
            host, index: try indexData(paths: ["kick.json", "sub/snare.json"]),
            files: ["kick.json": try presetData("Kick"), "sub/snare.json": try presetData("Snare")])

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        #expect(result.presets.map(\.preset.name) == ["Kick", "Snare"], "in the index's order")
        #expect(result.status == .ok)
    }

    @Test func oneBadPresetIsSkippedAndTheRestLoads() async throws {
        let host = "skip.test"
        route(
            host, index: try indexData(paths: ["kick.json", "bad.json"]),
            files: ["kick.json": try presetData("Kick"), "bad.json": try brokenPresetData("Bad")])

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        #expect(result.presets.map(\.preset.name) == ["Kick"])
        #expect(result.skipped.map(\.file) == ["bad.json"])
    }

    @Test func aRedirectToHTTPFailsTheSource() async throws {
        let host = "redirect.test"
        StubRoutes.shared.set(url(host).absoluteString, .redirect(URL(string: "http://\(host)/presets/index.json")!))

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        #expect(result.status == .failed(SourceError.refusedAddress.message), "the redirect is what stopped it")
        #expect(result.presets.isEmpty)
    }

    @Test func aRedirectToAnotherHTTPSAddressIsFollowed() async throws {
        let host = "follow.test"
        StubRoutes.shared.set(url(host).absoluteString, .redirect(url(host, "moved.json")))
        StubRoutes.shared.set(
            url(host, "moved.json").absoluteString,
            .ok(try indexData(paths: ["kick.json"]), contentType: "application/json"))
        StubRoutes.shared.set(
            url(host, "kick.json").absoluteString, .ok(try presetData("Kick"), contentType: "application/json"))

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        #expect(result.presets.map(\.preset.name) == ["Kick"])
    }

    @Test func aPlainHTTPAddressIsRefusedBeforeAnyRequest() async throws {
        let result = try await reader().read(PresetSource(name: "U", kind: .url(URL(string: "http://plain.test/index.json")!)))
        guard case .failed = result.status else {
            Issue.record("http must fail")
            return
        }
    }

    @Test func anAddressWithUserInfoOrAQueryIsRefused() async throws {
        for address in ["https://user:pw@info.test/index.json", "https://query.test/index.json?token=1"] {
            let result = try await reader().read(PresetSource(name: "U", kind: .url(URL(string: address)!)))
            guard case .failed = result.status else {
                Issue.record("\(address) must fail")
                return
            }
        }
    }

    @Test func anIndexOver64KBIsRefused() async throws {
        let host = "bigindex.test"
        let padding = String(repeating: "a", count: 65 * 1024)
        let big = try JSONSerialization.data(withJSONObject: [
            "format": "thumbmix-source", "version": 1, "name": padding, "presets": [[String: String]](),
        ])
        route(host, index: big, files: [:])

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        guard case .failed = result.status else {
            Issue.record("a big index must fail")
            return
        }
    }

    @Test func aPresetOver32KBIsSkipped() async throws {
        let host = "bigpreset.test"
        route(
            host, index: try indexData(paths: ["big.json", "kick.json"]),
            files: ["big.json": Data(repeating: 32, count: 33 * 1024), "kick.json": try presetData("Kick")])

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        #expect(result.presets.map(\.preset.name) == ["Kick"])
        #expect(result.skipped.map(\.file) == ["big.json"])
    }

    @Test func pathsThatLeaveTheIndexAreRefused() async throws {
        for (number, path) in [
            "../up.json", "/abs.json", "https://evil.test/p.json", "a/../../b.json", "//evil.test/p.json", "a\\b.json", "a.json?x=1",
        ].enumerated() {
            let host = "path\(number).test"
            route(host, index: try indexData(paths: [path]), files: [:])

            let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

            guard case .failed = result.status else {
                Issue.record("\(path) must fail the index")
                return
            }
        }
    }

    @Test func moreThanTwoHundredEntriesRefuseTheIndex() async throws {
        let host = "many.test"
        route(host, index: try indexData(paths: (1...201).map { "p\($0).json" }), files: [:])

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        guard case .failed = result.status else {
            Issue.record("201 entries must fail")
            return
        }
    }

    @Test func anIndexThatIsNotOursIsRefused() async throws {
        let host = "wrongformat.test"
        route(
            host,
            index: try JSONSerialization.data(withJSONObject: [
                "format": "other", "version": 1, "name": "x", "presets": [[String: String]](),
            ]), files: [:])

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        guard case .failed = result.status else {
            Issue.record("wrong format must fail")
            return
        }
    }

    @Test func aBodyThatIsNotUTF8IsRefused() async throws {
        let host = "latin.test"
        StubRoutes.shared.set(url(host).absoluteString, .ok(Data([0x7B, 0xE9, 0x7D]), contentType: "application/json"))

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        guard case .failed = result.status else {
            Issue.record("latin-1 must fail")
            return
        }
    }

    @Test func aWebPageIsNotAnIndex() async throws {
        let host = "html.test"
        StubRoutes.shared.set(url(host).absoluteString, .ok(try indexData(paths: []), contentType: "text/html"))

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        guard case .failed = result.status else {
            Issue.record("html must fail")
            return
        }
    }

    @Test func aBadIndexKeepsTheLastGoodRead() async throws {
        let host = "cache.test"
        let cache = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: cache) }
        route(host, index: try indexData(paths: ["kick.json"]), files: ["kick.json": try presetData("Kick")])
        let source = PresetSource(name: "U", kind: .url(url(host)))
        let reader = try reader(cache: cache)
        #expect(await reader.read(source).presets.count == 1)

        StubRoutes.shared.set(url(host).absoluteString, .status(500))
        let again = await reader.read(source)

        #expect(again.presets.map(\.preset.name) == ["Kick"], "the cache stands in")
        guard case .cached = again.status else {
            Issue.record("should say it is the cache: \(again.status)")
            return
        }
    }

    @Test func aCacheIsCheckedAgainLikeANewFile() async throws {
        let host = "cachecheck.test"
        let cache = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: cache) }
        let source = PresetSource(name: "U", kind: .url(url(host)))
        route(host, index: try indexData(paths: ["kick.json"]), files: ["kick.json": try presetData("Kick")])
        let reader = try reader(cache: cache)
        _ = await reader.read(source)
        let cached = try #require(try FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil).first)
        try Data("{\"files\":[{\"file\":\"x.json\",\"data\":\"AAAA\"}]}".utf8).write(to: cached)

        StubRoutes.shared.set(url(host).absoluteString, .status(500))
        let again = await reader.read(source)

        #expect(again.presets.isEmpty, "a tampered cache gives nothing")
    }

    @Test func aSourceNeverReadHasNothingToFallBackOn() async throws {
        let host = "nocache.test"
        StubRoutes.shared.set(url(host).absoluteString, .status(404))

        let result = try await reader().read(PresetSource(name: "U", kind: .url(url(host))))

        #expect(result.presets.isEmpty)
        guard case .failed = result.status else {
            Issue.record("should fail")
            return
        }
    }
}

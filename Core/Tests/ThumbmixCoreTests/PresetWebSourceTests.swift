import Foundation
import Testing

@testable import ThumbmixCore

/// Web sources: an index on an HTTPS address and the presets it lists, against a stubbed session.
struct PresetWebSourceTests {
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("thumbmix-test-" + UUID().uuidString)

    private func read(_ url: URL, deadline: Duration = .seconds(30)) async -> SourceResult {
        await makeSources(in: folder, deadline: deadline).read(url)
    }

    private func isFailed(_ result: SourceResult) -> Bool {
        if case .failed = result.status { return result.presets.isEmpty }
        return false
    }

    @Test func anIndexListsPresetsRelativeToItself() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        route(
            "list.test", index: try indexData(name: "Ours", paths: ["kick.json", "sub/snare.json"]),
            files: ["kick.json": try presetData("Kick"), "sub/snare.json": try presetData("Snare")])

        let result = await read(sourceURL("list.test"))

        #expect(result.presets.map(\.preset.name) == ["Kick", "Snare"], "in the index's order")
        #expect(result.presets.map(\.source) == [sourceURL("list.test"), sourceURL("list.test")])
        #expect(result.status == .ok)
        #expect(result.title == "Ours")
    }

    @Test func oneBadPresetIsSkippedAndTheRestLoads() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        route(
            "skip.test", index: try indexData(paths: ["kick.json", "bad.json", "big.json"]),
            files: [
                "kick.json": try presetData("Kick"), "bad.json": try brokenPresetData("Bad"),
                "big.json": Data(repeating: 32, count: 33 * 1024),
            ])

        let result = await read(sourceURL("skip.test"))

        #expect(result.presets.map(\.preset.name) == ["Kick"])
        #expect(result.skipped.map(\.file) == ["bad.json", "big.json"])
    }

    @Test func aRedirectToHTTPFailsTheSource() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        StubRoutes.shared.set(sourceURL("redirect.test"), .redirect(URL(string: "http://redirect.test/presets/index.json")!))

        let result = await read(sourceURL("redirect.test"))

        #expect(result.status == .failed(SourceError.refusedAddress.localizedDescription), "the redirect is what stopped it")
    }

    @Test func aRedirectToAnotherHTTPSAddressIsFollowed() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        route(
            "follow.test", index: Data(),
            files: ["moved.json": try indexData(paths: ["kick.json"]), "kick.json": try presetData("Kick")])
        StubRoutes.shared.set(sourceURL("follow.test"), .redirect(sourceURL("follow.test", "moved.json")))

        let result = await read(sourceURL("follow.test"))

        #expect(result.presets.map(\.preset.name) == ["Kick"])
    }

    @Test func aRedirectToAnotherHostFailsThatFile() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        route("pinned.test", index: try indexData(paths: ["kick.json"]))
        StubRoutes.shared.set(sourceURL("pinned.test", "kick.json"), .redirect(sourceURL("elsewhere.test", "kick.json")))
        route("elsewhere.test", index: Data(), files: ["kick.json": try presetData("Kick")])

        let result = await read(sourceURL("pinned.test"))

        #expect(result.presets.isEmpty, "a source can't reach further than its index's host")
        #expect(result.skipped.map(\.file) == ["kick.json"])
    }

    @Test(arguments: [
        "http://plain.test/index.json", "https://user:pw@info.test/index.json", "https://query.test/index.json?token=1",
    ])
    func anAddressThatIsNotPlainHTTPSIsRefused(_ address: String) async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(isFailed(await read(URL(string: address)!)))
    }

    @Test(arguments: [
        "../up.json", "/abs.json", "https://evil.test/p.json", "a/../../b.json", "//evil.test/p.json", "a\\b.json",
        "a.json?x=1",
    ])
    func aPathThatLeavesTheIndexRefusesIt(_ path: String) async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let host = "path-\(UUID().uuidString).test"
        route(host, index: try indexData(paths: [path]))

        #expect(isFailed(await read(sourceURL(host))), "\(path)")
    }

    @Test func anIndexThatIsNotOneTheAppReadsIsRefused() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let notOurs = try JSONSerialization.data(withJSONObject: [
            "format": "other", "version": 1, "name": "x", "presets": [[String: String]](),
        ])
        let huge = try indexData(name: String(repeating: "a", count: 65 * 1024), paths: [])
        let indexes = [
            "notours": notOurs, "huge": huge, "many": try indexData(paths: (1...201).map { "p\($0).json" }),
            "twice": try indexData(paths: ["kick.json", "kick.json"]), "latin": Data([0x7B, 0xE9, 0x7D]),
        ]
        for (host, index) in indexes {
            route(host + ".test", index: index, files: ["kick.json": try presetData("Kick")])
            #expect(isFailed(await read(sourceURL(host + ".test"))), "\(host)")
        }
        StubRoutes.shared.set(sourceURL("html.test"), .ok(try indexData(paths: []), contentType: "text/html"))
        #expect(isFailed(await read(sourceURL("html.test"))), "a web page is not an index")
    }

    @Test func aBadIndexKeepsTheLastGoodRead() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        route("cache.test", index: try indexData(paths: ["kick.json"]), files: ["kick.json": try presetData("Kick")])
        #expect(await read(sourceURL("cache.test")).presets.count == 1)

        StubRoutes.shared.set(sourceURL("cache.test"), .status(500))
        let again = await read(sourceURL("cache.test"))

        #expect(again.presets.map(\.preset.name) == ["Kick"], "the cache stands in")
        #expect(again.title == "Test source", "under the name its index gave")
        guard case .cached = again.status else {
            Issue.record("should say it is the cache: \(again.status)")
            return
        }
    }

    @Test func aCacheIsCheckedAgainLikeANewFile() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        route("tamper.test", index: try indexData(paths: ["kick.json"]), files: ["kick.json": try presetData("Kick")])
        _ = await read(sourceURL("tamper.test"))
        let cached = try #require(
            try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first)
        try Data("{\"files\":[{\"file\":\"x.json\",\"data\":\"AAAA\"}]}".utf8).write(to: cached)

        StubRoutes.shared.set(sourceURL("tamper.test"), .status(500))

        #expect(isFailed(await read(sourceURL("tamper.test"))), "a tampered cache gives nothing")
    }

    /// A venue's flaky Wi-Fi gives the index but not every file: the offline copy keeps what it had.
    @Test func aReadThatLostAFileKeepsThatFilesLastCopy() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        route("partial.test", index: try indexData(paths: ["kick.json"]), files: ["kick.json": try presetData("Kick")])
        _ = await read(sourceURL("partial.test"))

        StubRoutes.shared.set(sourceURL("partial.test", "kick.json"), .status(503))
        let flaky = await read(sourceURL("partial.test"))
        #expect(flaky.presets.map(\.preset.name) == ["Kick"], "no fewer presets than with no Wi-Fi at all")
        #expect(flaky.skipped.map(\.file) == ["kick.json"], "named, so the engineer sees its copy is older")

        StubRoutes.shared.set(sourceURL("partial.test"), .status(500))
        let offline = await read(sourceURL("partial.test"))
        #expect(offline.presets.map(\.preset.name) == ["Kick"], "the earlier good copy survived the flaky read")
    }

    /// The 10 s a request waits for the next byte is not a limit on the whole read: a server dripping bytes would hold it.
    @Test func aReadThatNeverEndsGivesUpAtItsDeadline() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        StubRoutes.shared.set(sourceURL("hang.test"), .hangs)

        let started = ContinuousClock.now
        let result = await read(sourceURL("hang.test"), deadline: .milliseconds(300))

        #expect(ContinuousClock.now - started < .seconds(3))
        #expect(isFailed(result))
    }

    @Test func aSourceNeverReadHasNothingToFallBackOn() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        StubRoutes.shared.set(sourceURL("nocache.test"), .status(404))

        #expect(isFailed(await read(sourceURL("nocache.test"))))
    }
}

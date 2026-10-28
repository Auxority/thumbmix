import Foundation
import Testing

@testable import ThumbmixCore

/// How On this iPhone's files are named, and what a refresh may and may not undo.
@MainActor
struct PresetLibraryFilesTests {
    private struct Folders {
        let root: URL
        var support: URL { root.appendingPathComponent("support") }
        var own: URL { root.appendingPathComponent("own") }
        var cache: URL { root.appendingPathComponent("cache") }
    }

    private func folders() throws -> Folders { Folders(root: try makeTemporaryFolder()) }

    private func library(_ folders: Folders) -> PresetLibrary {
        PresetLibrary(
            supportDirectory: folders.support, ownFolder: folders.own, cacheDirectory: folders.cache,
            session: StubRoutes.session(), includesDefaultSource: false)
    }

    @Test func aNameAtTheLimitStillSavesTwice() async throws {
        let folders = try folders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = library(folders)
        let name = String(repeating: "a", count: 40)

        _ = try await library.save(.kick.named(name))
        let second = try await library.save(.kick.named(name))

        #expect(second.preset.name.count <= 40)
        #expect(library.entries.count == 2, "both files read back: \(library.results.values.flatMap(\.skipped))")
    }

    @Test func aNameStartingWithADotStillShowsInTheList() async throws {
        let folders = try folders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = library(folders)

        let entry = try await library.save(.kick.named(".kick"))

        #expect(!entry.file.hasPrefix("."))
        #expect(library.entries.map(\.preset.name) == [".kick"])
    }

    @Test func renamingOnlyTheCaseKeepsTheName() async throws {
        let folders = try folders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = library(folders)
        let entry = try await library.save(.kick.named("kick"))

        let renamed = try await library.replace(entry, with: entry.preset.named("Kick"))

        #expect(renamed.preset.name == "Kick")
        #expect(library.entries.map(\.preset.name) == ["Kick"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: folders.own.path) == ["Kick.json"])
    }

    /// A web source that never answers must not hold up the presets on this iPhone, or undo a save made meanwhile.
    @Test func aSaveDuringARefreshIsNotUndoneByIt() async throws {
        let folders = try folders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = PresetLibrary(
            supportDirectory: folders.support, ownFolder: folders.own, cacheDirectory: folders.cache,
            session: StubRoutes.session(), includesDefaultSource: false, webDeadline: .seconds(1))
        StubRoutes.shared.set("https://slow-library.test/index.json", .hangs)
        try library.addWebAddress("https://slow-library.test/index.json")

        let refreshing = Task { await library.refresh() }
        #expect(await eventually { library.isRefreshing })
        _ = try await library.save(.kick.named("New"))
        await refreshing.value

        #expect(library.entries.map(\.preset.name) == ["New"])
    }

    @Test func removingAWebSourceDeletesItsOfflineCopy() async throws {
        let folders = try folders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = library(folders)
        let host = "forget.test"
        StubRoutes.shared.set("https://\(host)/index.json", .ok(try indexData(paths: ["a.json"]), contentType: "application/json"))
        StubRoutes.shared.set("https://\(host)/a.json", .ok(try presetData("A"), contentType: "application/json"))
        try library.addWebAddress("https://\(host)/index.json")
        await library.refresh()
        #expect(try FileManager.default.contentsOfDirectory(atPath: folders.cache.path).count == 1)

        library.remove(try #require(library.sources.last))

        #expect(try FileManager.default.contentsOfDirectory(atPath: folders.cache.path).isEmpty)
    }
}

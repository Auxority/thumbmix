import Foundation
import Testing

@testable import ThumbmixCore

/// The library's web sources: which are listed, kept across launches, and how their presets join the own ones.
@MainActor
struct PresetLibrarySourcesTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent("thumbmix-test-" + UUID().uuidString)

    /// A library as the app makes one: own presets and sources in folders of their own.
    private func library(defaults: [URL] = []) -> PresetLibrary {
        PresetLibrary(
            ownFolder: root.appendingPathComponent("own"),
            sources: makeSources(in: root.appendingPathComponent("sources"), defaults: defaults))
    }

    @Test func aFirstLaunchListsTheDefaultAndARemovedOneStaysRemoved() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let first = library(defaults: [PresetSources.thumbmix])
        #expect(first.sources == [.web(PresetSources.thumbmix)])
        #expect(!first.lacksDefaultSource)

        first.removeSource(.web(PresetSources.thumbmix))

        let next = library(defaults: [PresetSources.thumbmix])
        #expect(next.sources.isEmpty, "the next launch keeps it removed")
        #expect(next.lacksDefaultSource)
        next.addDefaultSources()
        #expect(library(defaults: [PresetSources.thumbmix]).sources == [.web(PresetSources.thumbmix)])
    }

    @Test func anAddedAddressIsKeptOnceAndOnlyPlainHTTPSIsTaken() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let library = library()

        try library.addSource("  https://added.test/presets/index.json \n")
        try library.addSource("https://added.test/presets/index.json")

        #expect(library.sources == [.web(sourceURL("added.test"))])
        for refused in ["http://added.test/index.json", "https://added.test/i.json?token=1", "not an address"] {
            #expect(throws: SourceError.refusedAddress) { try library.addSource(refused) }
        }
        #expect(self.library().sources == [.web(sourceURL("added.test"))], "kept across launches")
    }

    @Test func aSourcesPresetsJoinTheOwnOnesByFitThenName() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        route(
            "join.test", index: try indexData(name: "Join", paths: ["snare.json", "kick.json"]),
            files: ["snare.json": try presetData("Snare"), "kick.json": try presetData("Bass drum")])
        let library = library()
        try library.save(.kick.named("Kick"))
        try library.addSource(sourceURL("join.test").absoluteString)

        await library.refreshSources()

        let (fits, others) = library.ordered { $0.name != "Snare" }
        #expect(fits.map(\.preset.name) == ["Bass drum", "Kick"])
        #expect(others.map(\.preset.name) == ["Snare"])
        #expect(fits.map(\.isOwn) == [false, true])
        #expect(library.title(of: sourceURL("join.test").absoluteString) == "Join")
    }

    @Test func aRemovedSourceTakesItsPresetsAndItsOfflineCopy() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        route("gone.test", index: try indexData(paths: ["kick.json"]), files: ["kick.json": try presetData("Kick")])
        let library = library()
        try library.addSource(sourceURL("gone.test").absoluteString)
        await library.refreshSources()
        #expect(library.entries.count == 1)

        library.removeSource(.web(sourceURL("gone.test")))
        #expect(library.entries.isEmpty)

        StubRoutes.shared.set(sourceURL("gone.test"), .status(500))
        try library.addSource(sourceURL("gone.test").absoluteString)
        await library.refreshSources()
        #expect(library.entries.isEmpty, "added again, it starts from nothing")
    }

    /// The page's read is cancelled when the desk link blips or the page goes: that is no news about the source.
    @Test func aCancelledRefreshLeavesTheLastResult() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        route("cancel.test", index: try indexData(paths: ["kick.json"]), files: ["kick.json": try presetData("Kick")])
        let library = library()
        try library.addSource(sourceURL("cancel.test").absoluteString)
        await library.refreshSources()

        StubRoutes.shared.set(sourceURL("cancel.test"), .hangs)
        let refresh = Task { await library.refreshSources() }
        refresh.cancel()
        await refresh.value

        #expect(library.results[.web(sourceURL("cancel.test"))]?.status == .ok)
        #expect(library.entries.count == 1)
    }

    @Test func aSourceRemovedWhileItIsReadKeepsNoOfflineCopy() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        route("inflight.test", index: Data(), files: ["kick.json": try presetData("Kick")])
        StubRoutes.shared.set(sourceURL("inflight.test"), .slow(try indexData(paths: ["kick.json"]), .milliseconds(300)))
        let library = library()
        try library.addSource(sourceURL("inflight.test").absoluteString)

        let refresh = Task { await library.refreshSources() }
        try await Task.sleep(for: .milliseconds(50))
        library.removeSource(.web(sourceURL("inflight.test")))
        await refresh.value

        let left = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("sources").path)
        #expect(left.filter { $0.hasPrefix("cache-") }.isEmpty)
    }

    /// Pull to refresh while the page's own read runs: one read per source, not two racing for its offline copy.
    @Test func aSourceAlreadyBeingReadIsNotReadTwice() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        route("once.test", index: Data(), files: ["kick.json": try presetData("Kick")])
        StubRoutes.shared.set(sourceURL("once.test"), .slow(try indexData(paths: ["kick.json"]), .milliseconds(300)))
        let library = library()
        try library.addSource(sourceURL("once.test").absoluteString)

        let first = Task { await library.refreshSources() }
        try await Task.sleep(for: .milliseconds(50))
        await library.refreshSources()
        await first.value

        #expect(StubRoutes.shared.requests(to: sourceURL("once.test")) == 1)
        #expect(library.entries.count == 1)
    }

    @Test func aSourcesPresetIsReadOnlyAndSavingItMakesAnOwnCopy() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        route("ro.test", index: try indexData(paths: ["kick.json"]), files: ["kick.json": try presetData("Kick")])
        let library = library()
        try library.addSource(sourceURL("ro.test").absoluteString)
        await library.refreshSources()
        let web = try #require(library.entries.first)

        #expect(throws: LibraryError.readOnly) { try library.replace(web, with: web.preset.named("Changed")) }
        #expect(throws: LibraryError.readOnly) { try library.remove(web) }
        let copy = try library.save(web.preset)

        #expect(copy.isOwn)
        #expect(library.own.map(\.preset.name) == ["Kick"])
    }

    @Test func folderAndWebSourcesJoinTheListAndTheFolderIsKeptAcrossLaunches() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        route("mixed.test", index: try indexData(name: "Web", paths: ["kick.json"]), files: ["kick.json": try presetData("Kick")])
        let picked = root.appendingPathComponent("Picked")
        try FileManager.default.createDirectory(at: picked, withIntermediateDirectories: true)
        try presetData("Snare").write(to: picked.appendingPathComponent("snare.json"))
        let library = library()
        try library.addSource(sourceURL("mixed.test").absoluteString)
        let folder = try library.addFolder(picked)

        await library.refreshSources()

        #expect(library.entries.map(\.preset.name).sorted() == ["Kick", "Snare"])
        #expect(library.entries.allSatisfy { !$0.isOwn })
        #expect(library.title(of: folder.id) == "Picked")
        let next = self.library()
        await next.refreshSources()
        #expect(next.sources.map(\.id) == [sourceURL("mixed.test").absoluteString, folder.id])
        #expect(next.entries.count == 2, "the bookmark still opens the folder")
    }

    @Test func aPickedFileIsAReadOnlySourceNamedAfterTheFile() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("tom.json")
        try presetData("Tom").write(to: file)
        let library = library()

        let source = try library.addFile(file)
        await library.refreshSources()

        let entry = try #require(library.entries.first)
        #expect(entry.preset.name == "Tom")
        #expect(library.title(of: source.id) == "tom.json")
        #expect(throws: LibraryError.readOnly) { try library.remove(entry) }
    }

    /// 0.57 kept the sources as a list of addresses: they stay, as web sources.
    @Test func aListOfAddressesFromBeforeFoldersStillLoads() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("sources")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode([sourceURL("old.test"), PresetSources.thumbmix]).write(to: folder.appendingPathComponent("sources.json"))

        #expect(library(defaults: [PresetSources.thumbmix]).sources == [.web(sourceURL("old.test")), .web(PresetSources.thumbmix)])
    }
}

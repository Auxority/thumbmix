import Foundation
import Testing

@testable import ThumbmixCore

/// Folder, file and URL sources, read by the same validation as an imported file.
struct PresetSourceReaderTests {
    private func reader(cache: URL? = nil, session: URLSession = StubRoutes.session()) throws -> SourceReader {
        SourceReader(session: session, cacheDirectory: try cache ?? makeTemporaryFolder())
    }

    private func bookmark(_ url: URL) throws -> Data {
        try BookmarkAccess.bookmark(for: url)
    }

    // MARK: Folder and file

    @Test func aFolderGivesEveryValidPresetAndNamesTheSkippedOnes() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try presetData("Kick").write(to: folder.appendingPathComponent("kick.json"))
        try presetData("Snare").write(to: folder.appendingPathComponent("snare.json"))
        try brokenPresetData("Broken").write(to: folder.appendingPathComponent("broken.json"))
        try Data("notes".utf8).write(to: folder.appendingPathComponent("notes.txt"))

        let result = try await reader().read(PresetSource(name: "F", kind: .folder(bookmark: try bookmark(folder))))

        #expect(result.presets.map(\.preset.name).sorted() == ["Kick", "Snare"])
        #expect(result.skipped.map(\.file) == ["broken.json"])
        #expect(result.skipped.first?.reason.contains("gate.thresholdDb") == true, "names the field")
    }

    @Test func aFolderIsReadAgainEachTimeSoLocalEditsShow() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("kick.json")
        try presetData("Kick").write(to: file)
        let source = PresetSource(name: "F", kind: .folder(bookmark: try bookmark(folder)))
        let reader = try reader()
        #expect(await reader.read(source).presets.first?.preset.name == "Kick")

        try presetData("Kick edited").write(to: file)

        #expect(await reader.read(source).presets.first?.preset.name == "Kick edited")
    }

    @Test func aFolderStopsAtTwoHundredPresets() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let data = try presetData("Same")
        for number in 1...205 { try data.write(to: folder.appendingPathComponent("p\(number).json")) }

        let result = try await reader().read(PresetSource(name: "F", kind: .folder(bookmark: try bookmark(folder))))

        #expect(result.presets.count == 200)
        #expect(result.skipped.count == 5)
    }

    @Test func aFileBiggerThan32KBIsSkippedWithoutBeingRead() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(repeating: 32, count: PresetValidation.maxBytes + 1).write(to: folder.appendingPathComponent("big.json"))

        let result = try await reader().read(PresetSource(name: "F", kind: .folder(bookmark: try bookmark(folder))))

        #expect(result.presets.isEmpty)
        #expect(result.skipped.map(\.file) == ["big.json"])
    }

    @Test func aSingleFileSourceGivesThatPreset() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("mine.json")
        try presetData("Mine").write(to: file)

        let result = try await reader().read(PresetSource(name: "mine", kind: .file(bookmark: try bookmark(file))))

        #expect(result.presets.map(\.preset.name) == ["Mine"])
        #expect(result.status == .ok)
    }

    @Test func aFileThatIsNotAPresetFailsTheSourceWithTheReason() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("bad.json")
        try brokenPresetData("Bad").write(to: file)

        let result = try await reader().read(PresetSource(name: "bad", kind: .file(bookmark: try bookmark(file))))

        #expect(result.presets.isEmpty)
        guard case .failed(let reason) = result.status else {
            Issue.record("should fail")
            return
        }
        #expect(reason.contains("gate.thresholdDb"))
    }

    @Test func aMovedFolderIsNotFoundAndAsksForANewPick() async throws {
        let folder = try makeTemporaryFolder()
        let data = try bookmark(folder)
        try FileManager.default.removeItem(at: folder)

        let result = try await reader().read(PresetSource(name: "gone", kind: .folder(bookmark: data)))

        #expect(result.status == .failed(SourceStatus.notFoundText))
    }

    @Test func garbageInPlaceOfABookmarkIsNotFound() async throws {
        let result = try await reader().read(PresetSource(name: "x", kind: .file(bookmark: Data("nope".utf8))))
        #expect(result.status == .failed(SourceStatus.notFoundText))
    }

    @Test func theFolderOnThisIPhoneIsReadWithoutABookmark() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try presetData("Own").write(to: folder.appendingPathComponent("own.json"))
        let reader = SourceReader(session: StubRoutes.session(), cacheDirectory: try makeTemporaryFolder(), ownFolder: folder)

        let result = await reader.read(.onThisIPhone)

        #expect(result.presets.map(\.preset.name) == ["Own"])
    }
}

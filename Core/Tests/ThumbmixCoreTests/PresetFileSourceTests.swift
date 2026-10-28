import Foundation
import Testing

@testable import ThumbmixCore

/// Folder and file sources picked in Files, read by the same validation as an imported file.
struct PresetFileSourceTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent("thumbmix-test-" + UUID().uuidString)

    private func folder() throws -> URL {
        let folder = root.appendingPathComponent("picked-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func read(_ source: PresetSource) async -> SourceResult {
        await makeSources(in: root.appendingPathComponent("sources")).read(source)
    }

    @Test func aFolderGivesEveryValidPresetAndNamesTheSkippedOnes() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try folder()
        try presetData("Kick").write(to: folder.appendingPathComponent("kick.json"))
        try presetData("Snare").write(to: folder.appendingPathComponent("snare.json"))
        try brokenPresetData("Broken").write(to: folder.appendingPathComponent("broken.json"))
        try Data("notes".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        let source = try PresetSource.folder(folder)

        let result = await read(source)

        #expect(result.presets.map(\.preset.name) == ["Kick", "Snare"])
        #expect(result.presets.map(\.source) == [source.id, source.id])
        #expect(result.skipped.map(\.file) == ["broken.json"])
        #expect(result.skipped.first?.reason.contains("gate/thr") == true, "names the field")
        #expect(result.status == .ok)
    }

    @Test func aFolderIsReadAgainEachTimeSoLocalEditsShow() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try folder()
        let file = folder.appendingPathComponent("kick.json")
        try presetData("Kick").write(to: file)
        let source = try PresetSource.folder(folder)
        #expect(await read(source).presets.first?.preset.name == "Kick")

        try presetData("Kick edited").write(to: file)

        #expect(await read(source).presets.first?.preset.name == "Kick edited")
    }

    @Test func aFolderStopsAtTwoHundredPresets() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try folder()
        let data = try presetData("Same")
        for number in 1...205 { try data.write(to: folder.appendingPathComponent("p\(number).json")) }

        let result = await read(try .folder(folder))

        #expect(result.presets.count == 200)
        #expect(result.skipped.count == 5)
        #expect(result.skipped.first?.reason == "More than 200 files.")
    }

    @Test func aFileBiggerThan32KBIsSkippedWithoutBeingRead() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try folder()
        try Data(repeating: 32, count: PresetValidation.maxBytes + 1).write(to: folder.appendingPathComponent("big.json"))

        let result = await read(try .folder(folder))

        #expect(result.presets.isEmpty)
        #expect(result.skipped == [SkippedFile(file: "big.json", reason: PresetError.tooLarge.localizedDescription)])
    }

    /// iCloud Drive shows a file it hasn't downloaded as ".name.json.icloud": named, and asked for, not silently left out.
    @Test func anICloudPlaceholderIsNamedAsStillDownloading() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try folder()
        try presetData("Kick").write(to: folder.appendingPathComponent("kick.json"))
        try Data("placeholder".utf8).write(to: folder.appendingPathComponent(".snare.json.icloud"))

        let result = await read(try .folder(folder))

        #expect(result.presets.map(\.preset.name) == ["Kick"])
        #expect(result.skipped.map(\.file) == ["snare.json"])
        #expect(result.skipped.first?.reason == "Still downloading from iCloud. Refresh in a moment.")
    }

    @Test func aSingleFileSourceGivesThatPreset() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try folder().appendingPathComponent("mine.json")
        try presetData("Mine").write(to: file)
        let source = try PresetSource.file(file)

        let result = await read(source)

        #expect(result.presets.map(\.preset.name) == ["Mine"])
        #expect(result.status == .ok)
        #expect(source.name == "mine.json")
    }

    @Test func aFileThatIsNotAPresetFailsTheSourceWithTheReason() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try folder().appendingPathComponent("bad.json")
        try brokenPresetData("Bad").write(to: file)

        let result = await read(try .file(file))

        #expect(result.presets.isEmpty)
        guard case .failed(let reason) = result.status else {
            Issue.record("should fail")
            return
        }
        #expect(reason.contains("gate/thr"))
    }

    @Test func aMovedFolderIsNotFoundAndAsksForANewPick() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try folder()
        let source = try PresetSource.folder(folder)
        try FileManager.default.removeItem(at: folder)

        let result = await read(source)

        #expect(result.status == .failed("Not found. Pick it again."))
    }

    @Test func garbageInPlaceOfABookmarkIsNotFound() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let source = PresetSource(kind: .file(bookmark: Data("nope".utf8)), name: "x", id: "file-x")

        let result = await read(source)

        #expect(result.status == .failed("Not found. Pick it again."))
    }

    // MARK: The last good read

    /// iCloud evicted a file the folder gave before: its copy stays, and the status says why.
    @Test func aFileStillDownloadingKeepsItsLastGoodRead() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try folder()
        try presetData("Kick").write(to: folder.appendingPathComponent("kick.json"))
        try presetData("Snare").write(to: folder.appendingPathComponent("snare.json"))
        let source = try PresetSource.folder(folder)
        #expect(await read(source).presets.count == 2)
        try FileManager.default.removeItem(at: folder.appendingPathComponent("kick.json"))
        try Data("placeholder".utf8).write(to: folder.appendingPathComponent(".kick.json.icloud"))

        let result = await read(source)

        #expect(result.presets.map(\.preset.name).sorted() == ["Kick", "Snare"])
        #expect(result.status == .cached("Still downloading from iCloud. Refresh in a moment."))
        #expect(result.skipped.map(\.file) == ["kick.json"], "still named")
    }

    @Test func aFolderThatIsGoneShowsItsLastGoodRead() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try folder()
        try presetData("Kick").write(to: folder.appendingPathComponent("kick.json"))
        let source = try PresetSource.folder(folder)
        #expect(await read(source).presets.count == 1)
        try FileManager.default.removeItem(at: folder)

        let result = await read(source)

        #expect(result.presets.map(\.preset.name) == ["Kick"])
        #expect(result.status == .cached("Not found. Pick it again."))
    }

    /// Deleted in Files is gone, not lost: no copy brings it back.
    @Test func aFileDeletedFromTheFolderLeavesTheList() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try folder()
        try presetData("Kick").write(to: folder.appendingPathComponent("kick.json"))
        try presetData("Snare").write(to: folder.appendingPathComponent("snare.json"))
        let source = try PresetSource.folder(folder)
        _ = await read(source)
        try FileManager.default.removeItem(at: folder.appendingPathComponent("kick.json"))

        let result = await read(source)

        #expect(result.presets.map(\.preset.name) == ["Snare"])
        #expect(result.status == .ok)
    }
}

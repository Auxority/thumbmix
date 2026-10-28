import Foundation
import Testing

@testable import ThumbmixCore

@MainActor
struct PresetLibraryTests {
    @Test func firstLaunchHasOnThisIPhoneAndTheThumbmixSource() throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }

        let library = makeLibrary(folders, defaultSource: true)

        #expect(library.sources.map(\.id) == [PresetSource.onThisIPhone.id, PresetSource.thumbmix.id])
    }

    @Test func aRemovedDefaultSourceStaysRemovedAndComesBackOnRequest() throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let first = makeLibrary(folders, defaultSource: true)
        first.remove(.thumbmix)
        #expect(!first.sources.contains(.thumbmix))

        let second = makeLibrary(folders, defaultSource: true)
        #expect(!second.sources.contains(.thumbmix), "the saved list decides after the first launch")
        #expect(!second.hasThumbmixSource)

        second.addThumbmixSource()
        #expect(makeLibrary(folders, defaultSource: true).hasThumbmixSource)
    }

    @Test func onThisIPhoneCannotBeRemoved() throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)
        library.remove(.onThisIPhone)
        #expect(library.sources == [.onThisIPhone])
    }

    @Test func aSavedPresetIsAJSONFileInTheOwnFolderAndListed() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)

        let entry = try await library.save(.kick.named("Kick test"))

        #expect(entry.file == "Kick test.json")
        let data = try Data(contentsOf: folders.own.appendingPathComponent("Kick test.json"))
        #expect(try PresetValidation.decode(data).name == "Kick test")
        #expect(library.entries.map(\.preset.name) == ["Kick test"])
        #expect(entry.source == .onThisIPhone)
    }

    @Test func aNameAlreadyTakenGetsANumber() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)

        _ = try await library.save(.kick.named("Kick"))
        let second = try await library.save(.kick.named("Kick"))
        let third = try await library.save(.kick.named("kick"))

        #expect(second.preset.name == "Kick 2")
        #expect(second.file == "Kick 2.json")
        #expect(third.preset.name == "kick 3", "names differing only in case are one name")
    }

    @Test func aNameThatIsNotAFileNameIsCleaned() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let entry = try await makeLibrary(folders).save(.kick.named("A/B: C"))
        #expect(entry.file == "A-B- C.json")
        #expect(entry.preset.name == "A/B: C", "the name inside is as typed")
    }

    @Test func aPresetTheDeskWouldRefuseIsNotSaved() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        var preset = Preset.kick
        preset.name = String(repeating: "a", count: 41)

        await #expect(throws: PresetError.badText(field: "name")) { try await makeLibrary(folders).save(preset) }
    }

    @Test func editingMatchWordsRewritesTheFileAndRenamingMovesIt() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)
        let entry = try await library.save(.kick.named("Kick"))

        var edited = entry.preset
        edited.matchWords = ["bd"]
        let same = try await library.replace(entry, with: edited)
        #expect(same.file == "Kick.json")
        #expect(library.entries.first?.preset.matchWords == ["bd"])

        edited.name = "Bass drum"
        let renamed = try await library.replace(same, with: edited)
        #expect(renamed.file == "Bass drum.json")
        #expect(!FileManager.default.fileExists(atPath: folders.own.appendingPathComponent("Kick.json").path))
        #expect(library.entries.map(\.preset.name) == ["Bass drum"])
    }

    @Test func removingAPresetDeletesItsFile() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)
        let entry = try await library.save(.kick)

        try await library.remove(entry)

        #expect(library.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folders.own.appendingPathComponent(entry.file).path))
    }

    @Test func aPresetFromAnotherSourceCannotBeChangedOrRemoved() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)
        let foreign = LibraryEntry(source: .thumbmix, file: "kick.json", preset: .kick)

        await #expect(throws: LibraryError.readOnly) { try await library.remove(foreign) }
        await #expect(throws: LibraryError.readOnly) { try await library.replace(foreign, with: .kick) }
    }

    @Test func savingACopyOfAForeignPresetPutsItOnThisIPhone() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)

        let copy = try await library.save(.kick)

        #expect(copy.source == .onThisIPhone)
    }

    @Test func importingAFileCopiesItAndANameAlreadyTakenGetsANumber() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)
        let data = try presetData("Imported")

        let first = try await library.importPreset(data)
        let second = try await library.importPreset(data)

        #expect(first.preset.name == "Imported")
        #expect(second.preset.name == "Imported 2")
    }

    @Test func importingAFileTheDeskWouldRefuseStoresNothing() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)

        await #expect(throws: PresetError.outOfRange(field: "gate.thresholdDb")) {
            try await library.importPreset(brokenPresetData("Broken"))
        }
        #expect(library.entries.isEmpty)
    }

    @Test func aSharedFileIsThePresetAsJSONUnderItsName() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let url = try makeLibrary(folders).exportFile(.kick.named("Kick"))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(url.lastPathComponent == "Kick.json")
        #expect(try PresetValidation.decode(Data(contentsOf: url)).name == "Kick")
    }

    @Test func aFolderSourceIsAddedKeptAndItsPresetsListedOnRefresh() async throws {
        let folders = try LibraryFolders()
        let shared = try makeTemporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: folders.root)
            try? FileManager.default.removeItem(at: shared)
        }
        try presetData("Shared").write(to: shared.appendingPathComponent("shared.json"))
        let library = makeLibrary(folders)

        try library.addFolder(shared)
        await library.refresh()

        #expect(library.entries.map(\.preset.name) == ["Shared"])
        #expect(library.entries.first?.source.isWritable == false)
        #expect(makeLibrary(folders).sources.count == 2, "kept across launches")
    }

    @Test func aWebAddressMustBeHTTPS() throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)

        #expect(throws: SourceError.refusedAddress) { try library.addWebAddress("http://example.com/index.json") }
        #expect(throws: SourceError.refusedAddress) { try library.addWebAddress("not an address") }
        try library.addWebAddress(" https://example.com/presets/index.json ")
        #expect(library.sources.count == 2)
        try library.addWebAddress("https://example.com/presets/index.json")
        #expect(library.sources.count == 2, "the same address twice is one source")
    }

    @Test func aRemovedSourcesPresetsDisappear() async throws {
        let folders = try LibraryFolders()
        let shared = try makeTemporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: folders.root)
            try? FileManager.default.removeItem(at: shared)
        }
        try presetData("Shared").write(to: shared.appendingPathComponent("shared.json"))
        let library = makeLibrary(folders)
        try library.addFolder(shared)
        await library.refresh()

        library.remove(try #require(library.sources.last))

        #expect(library.entries.isEmpty)
    }

    @Test func presetsThatFitComeFirstThenTheOthersEachByName() async throws {
        let folders = try LibraryFolders()
        defer { try? FileManager.default.removeItem(at: folders.root) }
        let library = makeLibrary(folders)
        for name in ["Zed", "Alpha", "Kick B", "Kick A"] {
            var preset = Preset.kick.named(name)
            preset.matchWords = name.hasPrefix("Kick") ? ["kick"] : ["other"]
            _ = try await library.save(preset)
        }

        let (fits, others) = library.ordered { PresetMatching.fits($0, name: "Kick In") }

        #expect(fits.map(\.preset.name) == ["Kick A", "Kick B"])
        #expect(others.map(\.preset.name) == ["Alpha", "Zed"])
    }
}

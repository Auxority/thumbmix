import Foundation
import Testing

@testable import ThumbmixCore

/// The presets On this iPhone, in a folder of each test's own.
@MainActor
struct PresetLibraryTests {
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("thumbmix-test-" + UUID().uuidString)

    private func library() -> PresetLibrary { PresetLibrary(ownFolder: folder) }

    private func names(_ library: PresetLibrary) -> [String] { library.own.map(\.preset.name).sorted() }

    @Test func aSavedPresetIsAJSONFileInTheOwnFolderAndListed() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = library()

        let entry = try library.save(.kick.named("Kick test"))

        #expect(entry.file == "Kick test.json")
        let data = try Data(contentsOf: folder.appendingPathComponent("Kick test.json"))
        #expect(try PresetValidation.decode(data).name == "Kick test")
        #expect(names(library) == ["Kick test"])
    }

    @Test func aNameAlreadyTakenGetsANumber() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = library()

        try library.save(.kick.named("Kick"))
        let second = try library.save(.kick.named("Kick"))
        let third = try library.save(.kick.named("kick"))

        #expect(second.preset.name == "Kick 2")
        #expect(second.file == "Kick 2.json")
        #expect(third.preset.name == "kick 3", "names differing only in case are one name")
    }

    @Test func aNameAtTheLimitStillSavesTwice() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = library()
        let name = String(repeating: "a", count: 40)

        try library.save(.kick.named(name))
        let second = try library.save(.kick.named(name))

        #expect(second.preset.name.count <= 40)
        #expect(library.own.count == 2, "both files read back: \(library.skipped)")
    }

    @Test func aNameThatIsNotAFileNameIsCleanedAndKeptInside() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = library()
        #expect(try library.save(.kick.named("A/B: C")).file == "A-B- C.json")
        let dotted = try library.save(.kick.named(".kick"))
        #expect(dotted.file == "kick.json", "a hidden file would never be listed")
        #expect(names(library) == [".kick", "A/B: C"])
    }

    /// An imported name may start with spaces before its dot: the file still must not be hidden.
    @Test func aNameOfSpacesAndDotsStillShowsInTheList() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = library()
        let entry = try library.save(.kick.named(" .kick"))
        #expect(entry.file == "kick.json")
        #expect(names(library) == [" .kick"])
    }

    @Test func aPresetTheDeskWouldRefuseIsNotSaved() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(throws: PresetError.badText(field: "name")) { try library().save(.kick.named(String(repeating: "a", count: 41))) }
    }

    @Test func editingRewritesTheFileAndRenamingMovesIt() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = library()
        let entry = try library.save(.kick.named("Kick"))

        var edited = entry.preset
        edited.matchWords = ["bd"]
        let same = try library.replace(entry, with: edited)
        #expect(same.file == "Kick.json")
        #expect(library.own.first?.preset.matchWords == ["bd"])

        let renamed = try library.replace(same, with: edited.named("Bass drum"))
        #expect(renamed.file == "Bass drum.json")
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["Bass drum.json"])
    }

    @Test func renamingOnlyTheCaseKeepsTheName() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = library()
        let entry = try library.save(.kick.named("kick"))

        let renamed = try library.replace(entry, with: entry.preset.named("Kick"))

        #expect(renamed.preset.name == "Kick")
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["Kick.json"])
    }

    @Test func removingAPresetDeletesItsFile() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = library()
        let entry = try library.save(.kick)

        try library.remove(entry)

        #expect(library.own.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }

    /// The folder shows in the Files app: a file edited there is read again, and one the app refuses is named.
    @Test func aFileEditedInFilesIsReadAgainAndABadOneNamed() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = library()
        try library.save(.kick)
        try kickJSON { $0["name"] = "Edited" }.write(to: folder.appendingPathComponent("Kick.json"))
        try Data("not json".utf8).write(to: folder.appendingPathComponent("Broken.json"))

        library.refresh()

        #expect(names(library) == ["Edited"])
        #expect(library.skipped.map(\.file) == ["Broken.json"])
    }

    @Test func aSharedFileIsThePresetAsJSONUnderItsName() throws {
        let url = try library().exportFile(.kick.named("Kick"))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(url.lastPathComponent == "Kick.json")
        #expect(try PresetValidation.decode(Data(contentsOf: url)).name == "Kick")
    }

    @Test func presetsThatFitComeFirstThenTheOthersEachByName() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = library()
        for name in ["Zed", "Alpha", "Kick B", "Kick A"] {
            var preset = Preset.kick.named(name)
            preset.matchWords = name.hasPrefix("Kick") ? ["kick"] : ["other"]
            try library.save(preset)
        }

        let (fits, others) = library.ordered { PresetMatching.fits($0, name: "Kick In") }

        #expect(fits.map(\.preset.name) == ["Kick A", "Kick B"])
        #expect(others.map(\.preset.name) == ["Alpha", "Zed"])
    }
}

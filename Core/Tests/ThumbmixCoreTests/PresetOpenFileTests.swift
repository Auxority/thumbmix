import Foundation
import Testing

@testable import ThumbmixCore

/// A `.json` opened in Thumbmix from AirDrop, Mail, Messages or Files: it lands On this iPhone, or the engineer is told why not.
@MainActor
struct PresetOpenFileTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent("thumbmix-test-" + UUID().uuidString)
    private var ownFolder: URL { root.appendingPathComponent("Documents/Presets") }
    private var inbox: URL { root.appendingPathComponent("Documents/Inbox") }

    private func library() -> PresetLibrary { PresetLibrary(ownFolder: ownFolder) }

    private func file(_ name: String, in folder: URL, _ data: Data) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    @Test func aPresetFileLandsInTheLibraryAndTheNoticeSaysWhere() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let library = library()
        let url = try file("kick.json", in: root, kickJSON())

        let notice = library.openFile(at: url)

        #expect(library.own.map(\.preset.name) == ["Kick"])
        #expect(notice.contains("Kick") && notice.contains("On this iPhone"), "the notice says what and where: \(notice)")
    }

    @Test func aNameAlreadyTakenIsToldAsItWasStored() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let library = library()
        let url = try file("kick.json", in: root, kickJSON())

        library.openFile(at: url)
        let notice = library.openFile(at: url)

        #expect(library.own.map(\.preset.name).sorted() == ["Kick", "Kick 2"])
        #expect(notice.contains("Kick 2"), "the stored name, not the file's: \(notice)")
    }

    @Test func aJSONThatIsNotAPresetIsRefusedWithTheFileNamedAndNothingIsAdded() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let library = library()

        for (name, body) in [("data.json", #"{"hello": 1}"#), ("broken.json", "not json at all")] {
            let notice = library.openFile(at: try file(name, in: root, Data(body.utf8)))
            #expect(notice.contains(name), "names the file: \(notice)")
            #expect(notice.contains(PresetError.notAPreset.localizedDescription), "says why: \(notice)")
        }
        #expect(library.own.isEmpty)
    }

    @Test func aFileTheDeskWouldRefuseIsRefusedWithItsReason() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let library = library()
        let broken = try kickJSON { $0["gate"] = ["gate/thr": 5] }

        let notice = library.openFile(at: try file("kick.json", in: root, broken))

        #expect(notice.contains(PresetError.outOfRange(field: "gate/thr").localizedDescription), "\(notice)")
        #expect(library.own.isEmpty)
    }

    @Test func aFileOverTheLimitIsRefusedUnread() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let big = Data(repeating: 0x20, count: PresetValidation.maxBytes + 1)

        let notice = library().openFile(at: try file("big.json", in: root, big))

        #expect(notice.contains(PresetError.tooLarge.localizedDescription), "\(notice)")
    }

    /// Mail and Messages hand the app a copy in Documents/Inbox, which the Files app shows: once it is in the
    /// library, or refused, the copy goes, or each file would be listed twice.
    @Test func theInboxCopyGoesButAFileElsewhereStays() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let library = library()
        let copy = try file("kick.json", in: inbox, kickJSON())
        let refused = try file("data.json", in: inbox, Data("{}".utf8))
        let elsewhere = try file("kick.json", in: root, kickJSON())

        library.openFile(at: copy)
        library.openFile(at: refused)
        library.openFile(at: elsewhere)

        #expect(!FileManager.default.fileExists(atPath: copy.path))
        #expect(!FileManager.default.fileExists(atPath: refused.path))
        #expect(FileManager.default.fileExists(atPath: elsewhere.path), "Files' own copy is the engineer's")
    }

    @Test func aFileThatIsGoneIsToldNotSkipped() {
        let notice = library().openFile(at: root.appendingPathComponent("gone.json"))
        #expect(notice.contains("gone.json"), "\(notice)")
    }
}

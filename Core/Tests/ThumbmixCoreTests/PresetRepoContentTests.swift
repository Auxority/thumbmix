import Foundation
import Testing

@testable import ThumbmixCore

/// The default source is this repo's `presets/` folder, served from GitHub: a bad file there reaches every install.
struct PresetRepoContentTests {
    private static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("presets")

    private func paths() throws -> [String] {
        let data = try Data(contentsOf: Self.folder.appendingPathComponent("index.json"))
        return try JSONDecoder().decode(PresetIndex.self, from: data).paths()
    }

    private func preset(_ path: String) throws -> Preset {
        try PresetValidation.decode(Data(contentsOf: Self.folder.appendingPathComponent(path)))
    }

    @Test func theIndexIsOneTheAppReadsAndListsEveryFile() throws {
        let paths = try paths()
        #expect(!paths.isEmpty)
        for path in paths { _ = try PresetSources.resolve(path, against: PresetSources.thumbmix) }
        let onDisk = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path)
            .filter { $0.hasSuffix(".json") && $0 != "index.json" }
        #expect(Set(onDisk) == Set(paths), "no file is left out of the index")
    }

    @Test func everyPresetPassesTheImportCheckWithAUniqueName() throws {
        let names = try paths().map { try preset($0).name }
        #expect(Set(names).count == names.count)
    }

    @Test func theyNeverHoldGainOrFortyEightVolts() throws {
        for path in try paths() {
            #expect(try !preset(path).holds(.input), "\(path): gain and 48V belong to the engineer's own desk")
        }
    }
}

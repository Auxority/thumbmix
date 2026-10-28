import Foundation
import Testing

@testable import ThumbmixCore

/// The default source is this repo's `presets/` folder, served from GitHub: a bad file there reaches every install.
struct PresetRepoContentTests {
    private static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("presets")

    private func index() throws -> PresetIndex {
        try JSONDecoder().decode(PresetIndex.self, from: Data(contentsOf: Self.folder.appendingPathComponent("index.json")))
    }

    @Test func theIndexIsOneTheAppReads() throws {
        let paths = try index().paths()
        #expect(!paths.isEmpty)
        let address = URL(string: "https://example.com/presets/index.json")!
        for path in paths { _ = try SourceReader.resolve(path, against: address) }
    }

    @Test func everyListedPresetPassesTheSameValidationAsAnImport() throws {
        for path in try index().paths() {
            let data = try Data(contentsOf: Self.folder.appendingPathComponent(path))
            _ = try PresetValidation.decode(data)
        }
    }

    @Test func noPresetFileIsLeftOutOfTheIndexAndNamesAreUnique() throws {
        let listed = Set(try index().paths())
        let onDisk = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path)
            .filter { $0.hasSuffix(".json") && $0 != "index.json" }
        #expect(Set(onDisk) == listed)
        let names = try listed.map { try PresetValidation.decode(Data(contentsOf: Self.folder.appendingPathComponent($0))).name }
        #expect(Set(names).count == names.count)
    }

    @Test func theyNeverHoldGainOrFortyEightVolts() throws {
        for path in try index().paths() {
            let preset = try PresetValidation.decode(Data(contentsOf: Self.folder.appendingPathComponent(path)))
            #expect(preset.input == nil, "\(path): gain and 48V belong to the engineer's own desk")
        }
    }
}

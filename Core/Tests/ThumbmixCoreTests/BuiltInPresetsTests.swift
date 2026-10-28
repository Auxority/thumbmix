import Foundation
import Testing

@testable import ThumbmixCore

/// The presets that ship with the app reach every install: each must pass the same check as an import.
struct BuiltInPresetsTests {
    private var files: [URL] {
        get throws {
            let folder = try #require(BuiltInPresets.folder)
            return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        }
    }

    @Test func everyFilePassesTheSameValidationAsAnImport() throws {
        let files = try files
        #expect(!files.isEmpty)
        for file in files { _ = try PresetValidation.decode(Data(contentsOf: file)) }
        #expect(BuiltInPresets.all.count == files.count, "none is dropped")
    }

    @Test func namesAreUnique() {
        let names = BuiltInPresets.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test func theyNeverHoldGainOrFortyEightVolts() {
        for preset in BuiltInPresets.all {
            #expect(!preset.holds(.input), "\(preset.name): gain and 48V belong to the engineer's own desk")
        }
    }
}

import Foundation
import Testing

@testable import ThumbmixCore

struct PresetJSONTests {
    @Test func aPresetSurvivesAWriteAndARead() throws {
        let data = try PresetJSON.encode(.kick)
        #expect(try PresetValidation.decode(data) == .kick)
    }

    @Test func theFileSaysWhatItIs() throws {
        let object = try #require(try JSONSerialization.jsonObject(with: PresetJSON.encode(.kick)) as? [String: Any])
        #expect(object["format"] as? String == "thumbmix-preset")
        #expect(object["version"] as? Int == 1)
        #expect(object["stripKind"] as? String == "input")
    }

    @Test func minusInfinityIsWrittenAsText() throws {
        let text = try #require(String(data: PresetJSON.encode(.kick), encoding: .utf8))
        #expect(text.contains("\"-inf\""))
        let mix = try #require(try PresetValidation.decode(PresetJSON.encode(.kick)).mix)
        #expect(mix.faderDb == -.infinity)
    }

    @Test func aPartTheFileLacksStaysNil() throws {
        let data = try kickJSON {
            $0["comp"] = nil
            $0["sends"] = nil
        }
        let preset = try PresetValidation.decode(data)
        #expect(preset.comp == nil)
        #expect(preset.sends == nil)
        #expect(preset.gate != nil)
    }
}

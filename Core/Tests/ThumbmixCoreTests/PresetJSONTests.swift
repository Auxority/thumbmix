import Foundation
import Testing

@testable import ThumbmixCore

struct PresetJSONTests {
    @Test func aPresetSurvivesAWriteAndARead() throws {
        let data = try PresetJSON.encode(.kick)
        #expect(try PresetValidation.decode(data) == .kick)
    }

    @Test func theFileSaysWhatItIsAndHoldsEachPartByPath() throws {
        let object = try #require(try JSONSerialization.jsonObject(with: PresetJSON.encode(.kick)) as? [String: Any])
        #expect(object["format"] as? String == "thumbmix-preset")
        #expect(object["version"] as? Int == 1)
        #expect(object["stripKind"] as? String == "input")
        let gate = try #require(object["gate"] as? [String: Any])
        #expect(gate["gate/thr"] as? Double == -40)
        #expect(gate["gate/mode"] as? String == "GATE")
        #expect(gate["gate/on"] as? Bool == true)
    }

    @Test func minusInfinityIsWrittenAsText() throws {
        let text = try #require(String(data: PresetJSON.encode(.kick), encoding: .utf8))
        #expect(text.contains("\"mix/fader\" : \"-inf\""))
        #expect(try PresetValidation.decode(PresetJSON.encode(.kick))[.mix, "mix/fader"] == .number(-.infinity))
    }

    @Test func aPartTheFileLacksIsNotHeld() throws {
        let data = try kickJSON {
            $0["comp"] = nil
            $0["sends"] = nil
        }
        let preset = try PresetValidation.decode(data)
        #expect(preset.parts == [.input, .eq, .gate, .mix])
    }
}

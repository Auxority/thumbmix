import Foundation
import Testing

@testable import ThumbmixCore

struct PresetValidationTests {
    private func refusal(_ edit: (inout [String: Any]) -> Void) throws -> PresetError? {
        do {
            _ = try PresetValidation.decode(kickJSON(edit))
            return nil
        } catch let error as PresetError {
            return error
        }
    }

    private func edit(_ object: inout [String: Any], _ part: String, _ change: (inout [String: Any]) -> Void) {
        var value = object[part] as? [String: Any] ?? [:]
        change(&value)
        object[part] = value
    }

    @Test func aValidFilePasses() throws {
        #expect(try refusal { _ in } == nil)
    }

    @Test func anOutOfRangeNumberIsRefusedAndNamed() throws {
        #expect(try refusal { edit(&$0, "gate") { $0["gate/thr"] = 5 } } == .outOfRange(field: "gate/thr"))
        #expect(try refusal { edit(&$0, "gate") { $0["gate/thr"] = -81 } } != nil)
        #expect(try refusal { edit(&$0, "gate") { $0["gate/thr"] = -80 } } == nil, "the edge is inside")
        #expect(try refusal { edit(&$0, "eq") { $0["eq/2/f"] = 30_000 } } == .outOfRange(field: "eq/2/f"))
    }

    @Test func aValueOfTheWrongKindIsRefused() throws {
        #expect(try refusal { edit(&$0, "gate") { $0["gate/thr"] = true } } == .wrongType(field: "gate/thr"))
        #expect(try refusal { edit(&$0, "gate") { $0["gate/on"] = 1 } } == .wrongType(field: "gate/on"), "a number is no switch")
        #expect(try refusal { edit(&$0, "gate") { $0["gate/thr"] = "-40" } } == .wrongType(field: "gate/thr"))
        #expect(try refusal { edit(&$0, "gate") { $0["gate/mode"] = 3 } } == .wrongType(field: "gate/mode"))
    }

    @Test func minusInfinityIsOnlyInsideALevelsRange() throws {
        #expect(try refusal { edit(&$0, "gate") { $0["gate/thr"] = "-inf" } } == .outOfRange(field: "gate/thr"))
        #expect(try refusal { edit(&$0, "mix") { $0["mix/fader"] = "-inf" } } == nil)
    }

    @Test func aPartMayHoldSomeValuesButNotNone() throws {
        #expect(try refusal { $0["gate"] = ["gate/thr": -50] } == nil, "a hand-written file may set just the threshold")
        #expect(try refusal { $0["gate"] = [String: Any]() } == .missing(field: "gate"))
    }

    @Test func aPathTheStripLacksIsRefused() throws {
        #expect(try refusal { edit(&$0, "gate") { $0["gate/keysrc"] = 3 } } == .notForStrip(field: "gate/keysrc"), "names a strip")
        #expect(try refusal { edit(&$0, "eq") { $0["eq/5/f"] = 1000 } } == .notForStrip(field: "eq/5/f"), "an input has 4 bands")
        #expect(try refusal { edit(&$0, "sends") { $0["mix/17/level"] = 0 } } == .notForStrip(field: "mix/17/level"))
        #expect(try refusal { edit(&$0, "sends") { $0["mix/3/level"] = 0 } } == .notForStrip(field: "mix/3/level"), "the desk writes 03")
        #expect(try refusal { edit(&$0, "sends") { $0["mix/04/type"] = "POST" } } != nil, "only odd sends have a tap")
        #expect(try refusal { edit(&$0, "comp") { $0["gate/thr"] = -50 } } == .notForStrip(field: "gate/thr"), "wrong part")
    }

    @Test func anUnknownOptionNameIsRefused() throws {
        let error = try refusal { edit(&$0, "gate") { $0["gate/mode"] = "SQUASH" } }
        #expect(error == .unknownOption(field: "gate/mode", value: "SQUASH"))
        let mainsType = try refusal { edit(&$0, "eq") { $0["eq/1/type"] = "BU12" } }
        #expect(mainsType == .unknownOption(field: "eq/1/type", value: "BU12"), "an input lacks the crossovers")
    }

    @Test func aFormatOrVersionWeDontKnowIsRefused() throws {
        #expect(try refusal { $0["format"] = "other" } == .notAPreset)
        #expect(try refusal { $0["version"] = 2 } == .unknownVersion(2))
        #expect(try refusal { $0["format"] = nil } == .notAPreset)
    }

    @Test func textThatIsNotJSONIsRefused() {
        #expect(throws: PresetError.notAPreset) { try PresetValidation.decode(Data("hello".utf8)) }
    }

    @Test func aFileOver32KBIsRefused() {
        let big = Data(repeating: 32, count: PresetValidation.maxBytes + 1)
        #expect(throws: PresetError.tooLarge) { try PresetValidation.decode(big) }
    }

    @Test func nameAndMatchWordsHaveLimits() throws {
        #expect(try refusal { $0["name"] = String(repeating: "a", count: 41) } == .badText(field: "name"))
        #expect(try refusal { $0["name"] = String(repeating: "a", count: 40) } == nil)
        #expect(try refusal { $0["name"] = "  " } == .badText(field: "name"))
        #expect(try refusal { $0["name"] = "Kick\u{7}" } == .badText(field: "name"))
        #expect(try refusal { $0["name"] = "Kick\nIn" } == .badText(field: "name"))
        let eleven = (1...11).map { "w\($0)" }
        #expect(try refusal { $0["matchWords"] = eleven } == .badText(field: "matchWords"))
        #expect(try refusal { $0["matchWords"] = [String(repeating: "a", count: 21)] } == .badText(field: "matchWords[1]"))
        #expect(try refusal { $0["matchWords"] = ["kick", ""] } == .badText(field: "matchWords[2]"))
        #expect(try refusal { $0["matchWords"] = ["kick", "kick"] } == .badText(field: "matchWords[2]"))
        #expect(try refusal { $0["matchWords"] = [String]() } == nil, "no words fits nothing, but is a preset")
    }

    @Test func aStripKindWithoutTheControlsRefusesTheirParts() throws {
        #expect(try refusal { $0["stripKind"] = "bus" } == .notForStrip(field: "input"), "a bus has no Input tab")
        #expect(try refusal { $0["stripKind"] = "dca" } != nil)
        #expect(try refusal { $0["stripKind"] = "tuba" } != nil)
    }

    @Test func aValueBetweenTwoStepsIsAcceptedAndSnappedWhenWritten() throws {
        #expect(try refusal { edit(&$0, "gate") { $0["gate/thr"] = -40.2 } } == nil)
        let spec = Catalog.gate(StripID(.input, 1)).threshold
        let written = Catalog.deskArguments([(spec, -40.2)])
        let position = try #require(spec.scale.normalized(from: written[0].argument))
        #expect(spec.scale.value(fromNormalized: position) == -40)
    }

    @Test func theErrorSaysWhichFieldInWords() {
        #expect(PresetError.outOfRange(field: "gate/thr").localizedDescription.contains("gate/thr"))
        #expect(PresetError.unknownOption(field: "gate/mode", value: "SQUASH").localizedDescription.contains("SQUASH"))
    }
}

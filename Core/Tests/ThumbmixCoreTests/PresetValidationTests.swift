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

    private func editBands(_ object: inout [String: Any], _ change: (inout [[String: Any]]) -> Void) {
        edit(&object, "eq") { eq in
            var bands = eq["bands"] as? [[String: Any]] ?? []
            change(&bands)
            eq["bands"] = bands
        }
    }

    @Test func aValidFilePasses() throws {
        #expect(try refusal { _ in } == nil)
    }

    @Test func anOutOfRangeNumberIsRefusedAndNamed() throws {
        let error = try refusal { edit(&$0, "gate") { $0["thresholdDb"] = 5 } }
        #expect(error == .outOfRange(field: "gate.thresholdDb"))
        #expect(try refusal { edit(&$0, "gate") { $0["thresholdDb"] = -81 } } != nil)
        #expect(try refusal { edit(&$0, "gate") { $0["thresholdDb"] = -80 } } == nil, "the edge is inside")
    }

    @Test func aBandInTheMiddleOfTheListIsNamedByNumber() throws {
        let error = try refusal { editBands(&$0) { $0[1]["hz"] = 30_000 } }
        #expect(error == .outOfRange(field: "eq.bands[2].hz"))
    }

    @Test func aBooleanWhereANumberBelongsIsRefused() throws {
        #expect(try refusal { edit(&$0, "gate") { $0["thresholdDb"] = true } } != nil)
        #expect(try refusal { edit(&$0, "gate") { $0["on"] = 1 } } != nil, "a number is no switch")
    }

    @Test func aNumberAsTextIsRefusedExceptMinusInfinityOnLevels() throws {
        #expect(try refusal { edit(&$0, "gate") { $0["thresholdDb"] = "-40" } } != nil)
        #expect(try refusal { edit(&$0, "gate") { $0["thresholdDb"] = "nan" } } != nil)
        #expect(try refusal { edit(&$0, "gate") { $0["thresholdDb"] = "-inf" } } != nil, "-inf is for levels only")
    }

    @Test func aMissingFieldIsRefusedAndNamed() throws {
        let error = try refusal { edit(&$0, "gate") { $0["rangeDb"] = nil } }
        #expect(error == .missing(field: "gate.rangeDb"))
    }

    @Test func anUnknownOptionNameIsRefused() throws {
        let error = try refusal { edit(&$0, "gate") { $0["mode"] = "SQUASH" } }
        #expect(error == .unknownOption(field: "gate.mode", value: "SQUASH"))
    }

    @Test func aMainEQTypeIsRefusedOnAnInput() throws {
        let error = try refusal { editBands(&$0) { $0[0]["type"] = "BU12" } }
        #expect(error == .unknownOption(field: "eq.bands[1].type", value: "BU12"))
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
        #expect(try refusal { $0["matchWords"] = ["ki\u{0}ck"] } == .badText(field: "matchWords[1]"))
        #expect(try refusal { $0["matchWords"] = [String]() } == nil, "no words fits nothing, but is a preset")
    }

    @Test func aStripKindWithoutTheControlsRefusesTheirParts() throws {
        #expect(try refusal { $0["stripKind"] = "bus" } != nil, "a bus has no gate or low cut")
        #expect(try refusal { $0["stripKind"] = "dca" } != nil)
        #expect(try refusal { $0["stripKind"] = "tuba" } != nil)
    }

    @Test func aBandCountOfAnotherLayoutIsRefused() throws {
        let error = try refusal { editBands(&$0) { $0 = Array($0.prefix(3)) } }
        #expect(error == .outOfRange(field: "eq.bands"))
    }

    @Test func aSendToANumberThatDoesNotExistIsRefused() throws {
        #expect(try refusal { $0["sends"] = ["17": ["levelDb": 0, "on": true]] } == .outOfRange(field: "sends.17"))
        #expect(try refusal { $0["sends"] = ["x": ["levelDb": 0, "on": true]] } == .outOfRange(field: "sends.x"))
        let evenTap = try refusal { $0["sends"] = ["4": ["levelDb": 0, "on": true, "tap": "POST"]] }
        #expect(evenTap == .notForStrip(field: "sends.4.tap"), "only odd sends have a tap")
    }

    @Test func aLevelAboveTheFaderTopIsRefused() throws {
        #expect(try refusal { $0["mix"] = ["faderDb": 10.5, "pan": 0] } == .outOfRange(field: "mix.faderDb"))
        #expect(try refusal { $0["mix"] = ["faderDb": 10, "pan": 0] } == nil)
    }

    @Test func aValueBetweenTwoStepsIsAcceptedAndSnappedWhenWritten() throws {
        #expect(try refusal { edit(&$0, "gate") { $0["thresholdDb"] = -40.2 } } == nil)
        let spec = Catalog.gate(StripID(.input, 1)).threshold
        let written = Catalog.deskArguments([(spec, -40.2)])
        let position = try #require(spec.scale.normalized(from: written[0].argument))
        #expect(spec.scale.value(fromNormalized: position) == -40)
    }

    @Test func aPartMayNotCarryAControlItsStripLacks() throws {
        // An aux in has no delay.
        let error = try refusal {
            $0["stripKind"] = "auxIn"
            $0["gate"] = nil
            $0["comp"] = nil
            $0["eq"] = nil
            $0["sends"] = nil
        }
        #expect(error == .notForStrip(field: "input.delayOn"))
    }

    @Test func theErrorSaysWhichFieldInWords() {
        #expect(PresetError.outOfRange(field: "gate.thresholdDb").message.contains("gate.thresholdDb"))
        #expect(PresetError.unknownOption(field: "gate.mode", value: "SQUASH").message.contains("SQUASH"))
    }
}

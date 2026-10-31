import Testing

@testable import ThumbmixCore

/// What a client sends is checked against the tool's own parameter list: wrong shapes and numbers outside the range
/// are refused with a message the model can act on, never clamped (the Thumbmix rule for typed values and presets).
struct ToolArgumentsTests {
    private let parameters: [ToolParameter] = [
        ToolParameter(name: "strip", description: "", kind: .string, isRequired: true),
        ToolParameter(name: "gain_db", description: "", kind: .number(-15...15)),
        ToolParameter(name: "band", description: "", kind: .integer(1...6)),
        ToolParameter(name: "ratio", description: "", kind: .numberChoice([2, 3, 4])),
        ToolParameter(name: "on", description: "", kind: .boolean),
    ]

    private func message(_ raw: [String: JSON]) -> String? {
        do {
            _ = try ToolArguments(raw, for: parameters)
            return nil
        } catch let error as ToolError {
            return error.message
        } catch {
            return "other error"
        }
    }

    @Test func validArgumentsAreReadAsTyped() throws {
        let arguments = try ToolArguments(
            ["strip": "Kick", "gain_db": 3.5, "band": 2, "ratio": 3, "on": true], for: parameters)

        #expect(arguments.string("strip") == "Kick")
        #expect(arguments.number("gain_db") == 3.5)
        #expect(arguments.integer("band") == 2)
        #expect(arguments.number("ratio") == 3)
        #expect(arguments.bool("on") == true)
        #expect(arguments.number("missing") == nil)
    }

    @Test func theEdgesOfARangeAreInside() {
        #expect(message(["strip": "a", "gain_db": -15]) == nil)
        #expect(message(["strip": "a", "gain_db": 15]) == nil)
    }

    @Test func aNumberOutsideTheRangeIsRefusedNotClamped() {
        let text = message(["strip": "a", "gain_db": 15.25])

        #expect(text?.contains("'gain_db' must be between -15 and 15 (got 15.25)") == true)
        #expect(text?.contains("not clamped") == true)
        #expect(message(["strip": "a", "band": 7])?.contains("between 1 and 6") == true)
        #expect(message(["strip": "a", "band": 0])?.contains("between 1 and 6") == true)
    }

    @Test func aNumberThatIsNotAChoiceIsRefusedWithTheChoices() {
        #expect(message(["strip": "a", "ratio": 5])?.contains("one of 2, 3, 4 (got 5)") == true)
    }

    @Test func aWrongTypeIsRefusedAndNothingIsCoerced() {
        #expect(message(["strip": "a", "gain_db": "3"]) == "'gain_db' must be a number.")
        #expect(message(["strip": "a", "on": 1]) == "'on' must be true or false.")
        #expect(message(["strip": 5]) == "'strip' must be a string.")
        #expect(message(["strip": "a", "band": 2.5]) == "'band' must be a whole number.")
        #expect(message(["strip": "a", "band": "2"]) == "'band' must be a whole number.")
    }

    @Test func aMissingRequiredArgumentIsNamed() {
        #expect(message([:]) == "'strip' is required.")
        #expect(message(["strip": .null]) == "'strip' is required.")
    }

    @Test func anUnknownArgumentIsRefusedWithWhatTheToolTakes() {
        let text = message(["strip": "a", "gain": 3])

        #expect(text?.hasPrefix("Unknown argument 'gain'.") == true)
        #expect(text?.contains("strip, gain_db, band, ratio, on") == true)
    }

    @Test func anEmptyOrLongStringIsRefused() {
        #expect(message(["strip": ""]) != nil)
        #expect(message(["strip": .string(String(repeating: "a", count: 101))]) != nil)
    }
}

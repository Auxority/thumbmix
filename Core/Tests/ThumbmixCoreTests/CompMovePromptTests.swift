import Testing

@testable import ThumbmixCore

/// Moving the comp across the EQ names the mixes whose sends tapped around the EQ hear the change (mock b1).
struct CompMovePromptTests {
    @Test func beforeEQOneMix() {
        let prompt = CompMovePrompt(movesBeforeEQ: true, mixes: ["Mon 1"])
        #expect(prompt.title == "Move the comp before the EQ?")
        #expect(prompt.message == "Mon 1 will start hearing the compressor.")
    }

    @Test func afterEQOneMix() {
        let prompt = CompMovePrompt(movesBeforeEQ: false, mixes: ["Mon 1"])
        #expect(prompt.title == "Move the comp after the EQ?")
        #expect(prompt.message == "Mon 1 will stop hearing the compressor.")
    }

    @Test func beforeEQManyMixes() {
        let prompt = CompMovePrompt(movesBeforeEQ: true, mixes: ["Mon 1", "Mon 2"])
        #expect(prompt.message == "These 2 mixes will start hearing the compressor:\n\nMon 1 · Mon 2")
    }

    @Test func afterEQManyMixes() {
        let prompt = CompMovePrompt(movesBeforeEQ: false, mixes: ["Mon 1", "Mon 2"])
        #expect(prompt.message == "These 2 mixes will stop hearing the compressor:\n\nMon 1 · Mon 2")
    }
}

import Testing

@testable import ThumbmixCore

/// The link alert adds a line only for what the desk's Link Preferences keep separate.
struct LinkPromptTests {
    @Test func everythingLinkedNeedsNoLine() {
        #expect(LinkPrompt.separateLine([], locale: .testEnglish) == nil)
    }

    @Test func partsAreListedInTheDesksOrder() {
        #expect(LinkPrompt.separateLine([.dynamics, .eq], locale: .testEnglish) == "EQ and dynamics stay separate.")
        #expect(
            LinkPrompt.separateLine([.faderMute, .gainDelay, .dynamics], locale: .testEnglish)
                == "Gain and delay, dynamics, and fader and mute stay separate.")
    }

    @Test func oneThingStays() {
        #expect(LinkPrompt.separateLine([.eq], locale: .testEnglish) == "EQ stays separate.")
        #expect(LinkPrompt.separateLine([.dynamics], locale: .testEnglish) == "Dynamics stay separate.")
    }
}

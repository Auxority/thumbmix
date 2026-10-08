import Testing

@testable import ThumbmixCore

/// The fader shows what the desk shows: its own table (doc p.145) for all 1024 steps, not just the law rounded.
struct FaderTextTests {
    private let fader = Catalog.fader(StripID(.input, 1))

    @Test func everyStepShowsTheDesksDecibels() {
        for (step, desk) in deskFaderDecibels.enumerated() {
            let shown = FaderLaw.shownDecibels(fromWire: Double(step) / 1023)
            #expect(shown == desk, "step \(step): desk \(desk), app \(shown)")
        }
    }

    /// The desk reads 0 from −0.09 to +0.07 dB (steps 765-769): a detent around unity.
    @Test func unityHasADetent() {
        for step in 765...769 {
            #expect(ValueText.format(Float(step) / 1023, fader, locale: .testEnglish) == "0.0 dB")
        }
        #expect(ValueText.format(Float(770) / 1023, fader, locale: .testEnglish) == "+0.1 dB")
    }

    /// A nudge starts from the shown value: from the top of the detent (+0.07 dB, shown 0.0) it lands on +1.0.
    @Test func aNudgeFromTheDetentMovesFromZero() {
        let up = RelativeDrag.nudged(Float(769) / 1023, byDecibels: 1, scale: .fader)
        #expect(ValueText.format(up, fader, locale: .testEnglish) == "+1.0 dB")
    }
}

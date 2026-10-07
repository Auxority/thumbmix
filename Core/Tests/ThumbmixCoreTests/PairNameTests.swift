import Testing

@testable import ThumbmixCore

/// A linked pair shows one name in the overview; neither side may look more important than the other.
struct PairNameTests {
    @Test(arguments: [
        ("OH L", "OH R", "OH"),
        ("Gtr L", "Gtr R", "Gtr"),
        ("Vox 1", "Vox 2", "Vox"),
        ("Kick In", "Kick Out", "Kick"),
        ("Playback L", "Playback R", "Playback"),
        ("OHL", "OHR", "OH"),
        ("Synth1", "Synth2", "Synth"),
        ("Vox", "Vox Dbl", "Vox"),
    ])
    func sharedStartAtAWordBoundary(odd: String, even: String, expected: String) {
        #expect(PairName.make(odd: odd, even: even, fallback: "Ch 7-8") == expected)
    }

    @Test func nothingSharedOrAMidWordCutShowsTheOddName() {
        #expect(PairName.make(odd: "Keys", even: "Pad", fallback: "Ch 7-8") == "Keys")
        #expect(PairName.make(odd: "Guitar", even: "Guiro", fallback: "Ch 7-8") == "Guitar")
        #expect(PairName.make(odd: "Pal", even: "Par", fallback: "Ch 7-8") == "Pal", "a lowercase l/r is part of a word")
    }

    /// A cut inside a number or word backs off to the last word boundary.
    @Test func aCutInsideANumberBacksOffToTheWord() {
        #expect(PairName.make(odd: "Ch 1", even: "Ch 12", fallback: "Ch 7-8") == "Ch")
        #expect(PairName.make(odd: "Vox 10", even: "Vox 11", fallback: "Ch 7-8") == "Vox")
    }

    @Test func oneNamedSideNamesThePair() {
        #expect(PairName.make(odd: "Keys", even: "", fallback: "Ch 7-8") == "Keys")
        #expect(PairName.make(odd: "", even: "Pad", fallback: "Ch 7-8") == "Pad")
    }

    @Test func anUnnamedPairUsesBothNumbers() {
        #expect(PairName.make(odd: "", even: "", fallback: "Ch 31-32") == "Ch 31-32")
        #expect(StripID(.input, 32).pairDefaultName == "Ch 31-32")
        #expect(StripID(.bus, 5).pairDefaultName == "Bus 5-6")
        #expect(StripID(.auxIn, 2).pairDefaultName == "Aux 1-2")
        #expect(StripID(.fxReturn, 7).pairDefaultName == "FX 7-8")
    }
}

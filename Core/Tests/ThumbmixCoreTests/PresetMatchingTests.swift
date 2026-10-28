import Testing

@testable import ThumbmixCore

struct PresetMatchingTests {
    private func preset(_ words: [String]) -> Preset {
        var preset = Preset.kick
        preset.matchWords = words
        return preset
    }

    @Test func aWordFitsWhenTheNameContainsItIgnoringCase() {
        #expect(PresetMatching.fits(preset(["kick"]), name: "Kick In"))
        #expect(PresetMatching.fits(preset(["KICK"]), name: "bd kick"))
        #expect(!PresetMatching.fits(preset(["snare"]), name: "Kick In"))
    }

    @Test func diacriticsDontMatter() {
        #expect(PresetMatching.fits(preset(["cafe"]), name: "Café"))
        #expect(PresetMatching.fits(preset(["Café"]), name: "cafe"))
    }

    @Test func anyWordIsEnough() {
        #expect(PresetMatching.fits(preset(["kick", "bass drum"]), name: "Bass Drum 2"))
    }

    @Test func noWordsAndEmptyWordsFitNothing() {
        #expect(!PresetMatching.fits(preset([]), name: "Kick"))
        #expect(!PresetMatching.fits(preset([""]), name: "Kick"))
        #expect(!PresetMatching.fits(preset([" "]), name: "Kick"))
    }

    @Test func anUnnamedStripFitsNothing() {
        #expect(!PresetMatching.fits(preset(["ch"]), name: ""))
    }

    @MainActor @Test func theMirrorListsTheStripsWhoseNamesFit() async throws {
        let names = [
            "/ch/01/config/name": "Kick In", "/ch/02/config/name": "Kick Out", "/bus/03/config/name": "Kick wedge",
            "/ch/03/config/name": "Snare",
        ]
        try await withLiveDesk(
            before: { fake in for (address, name) in names { fake.deskChange(address, .string(name)) } },
            body: { _, mirror in
                let fits = mirror.fittingStrips(Preset.kick)
                #expect(fits == [StripID(.input, 1), StripID(.input, 2), StripID(.bus, 3)])
            })
    }
}

import Testing

@testable import ThumbmixCore

struct SendTapTests {
    /// The desk numbers the taps 0...5 in this order (doc p.26): the choice names and the raw values must agree.
    @Test func theTapPointChoiceFollowsTheDesksOrder() throws {
        let spec = try #require(Catalog.sendTap(from: StripID(.input, 1), to: StripID(.bus, 1)))
        guard case .choice(let names) = spec.scale else {
            Issue.record("not a choice")
            return
        }
        #expect(names == ["IN/LC", "<-EQ", "EQ->", "PRE", "POST", "GRP"])
        #expect(SendTap.allCases.map(\.rawValue) == Array(0...5))
        #expect(SendTap.preFader.deskAbbreviation == "PRE")
    }
}

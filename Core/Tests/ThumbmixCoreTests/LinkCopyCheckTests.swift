import Testing

@testable import ThumbmixCore

struct LinkCopyCheckTests {
    private let partner = "/ch/10/mix/fader"

    @Test func aFollowingPartnerConfirmsTheDeskCopies() {
        var check = LinkCopyCheck()
        check.expect(partner, .float(0.25))
        check.rereadSent(partner)
        #expect(check.received(partner, .float(0.25)) == nil)
        #expect(check.deskCopies)
    }

    /// The desk stores a fader in 1024 steps: its copy of 0.25 can come back a hair off.
    @Test func roundingByTheDeskStillCounts() {
        var check = LinkCopyCheck()
        check.expect(partner, .float(0.25))
        check.rereadSent(partner)
        #expect(check.received(partner, .float(0.2502)) == nil)
        #expect(check.deskCopies)
    }

    @Test func aPartnerLeftBehindIsRepairedAndFlipsTheMode() {
        var check = LinkCopyCheck()
        check.expect(partner, .float(0.25))
        check.rereadSent(partner)
        #expect(check.received(partner, .float(0.75)) == .float(0.25))
        #expect(!check.deskCopies)
    }

    /// Pushes during a drag carry older values; only the answer to the re-read is judged.
    @Test func pushesBeforeTheReReadAreIgnored() {
        var check = LinkCopyCheck()
        check.expect(partner, .float(0.25))
        #expect(check.received(partner, .float(0.1)) == nil)
        #expect(check.deskCopies)
    }

    @Test func aLaterEditReplacesTheAwaitedValue() {
        var check = LinkCopyCheck()
        check.expect(partner, .float(0.25))
        check.rereadSent(partner)
        check.expect(partner, .float(0.5))
        #expect(check.received(partner, .float(0.4)) == nil, "the old re-read's answer is no longer judged")
    }
}

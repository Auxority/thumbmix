import Testing

@testable import ThumbmixCore

struct LinkCopyCheckTests {
    private let partner = "/ch/10/mix/fader"
    private let t0 = ContinuousClock.now
    private var answered: ContinuousClock.Instant { t0 + .milliseconds(50) }

    /// The re-read is sent at `t0`.
    private func awaiting(_ value: OSCArgument) -> LinkCopyCheck {
        var check = LinkCopyCheck()
        check.expect(partner, value)
        check.rereadSent(partner, now: t0)
        return check
    }

    @Test func aFollowingPartnerConfirmsTheDeskCopies() {
        var check = awaiting(.float(0.25))
        #expect(check.received(partner, .float(0.25), now: answered) == nil)
        #expect(check.deskCopies)
    }

    /// The desk stores a fader in 1024 steps: its copy of 0.25 can come back a hair off.
    @Test func roundingByTheDeskStillCounts() {
        var check = awaiting(.float(0.25))
        #expect(check.received(partner, .float(0.2502), now: answered) == nil)
    }

    /// What a partner left behind means depends on the section, so the mirror decides; the check only reports it.
    @Test func aPartnerLeftBehindReportsWhatItShouldHaveBeen() {
        var check = awaiting(.float(0.25))
        #expect(check.received(partner, .float(0.75), now: answered) == .float(0.25))
        #expect(check.deskCopies)
    }

    /// Pushes during a drag carry older values; only the answer to the re-read is judged.
    @Test func pushesBeforeTheReReadAreIgnored() {
        var check = LinkCopyCheck()
        check.expect(partner, .float(0.25))
        #expect(check.received(partner, .float(0.1), now: answered) == nil)
    }

    @Test func aLaterEditReplacesTheAwaitedValue() {
        var check = awaiting(.float(0.25))
        check.expect(partner, .float(0.5))
        #expect(check.received(partner, .float(0.4), now: answered) == nil, "the old re-read's answer is no longer judged")
    }

    /// A lost answer must not make a later change on the desk look like a partner left behind: writing the old
    /// value then would undo the engineer's move.
    @Test func aMessageAfterTheWindowIsNotJudged() {
        var check = awaiting(.float(0.25))
        #expect(check.received(partner, .float(0.75), now: t0 + .seconds(2)) == nil)
        #expect(check.received(partner, .float(0.75), now: answered) == nil, "and it is forgotten")
    }

    /// After a lost connection the resync is the truth: nothing from before it is judged.
    @Test func forgetDropsEverythingAwaited() {
        var check = awaiting(.float(0.25))
        check.expect("/ch/12/mix/on", .int(0))
        check.forget()
        check.rereadSent("/ch/12/mix/on", now: t0)
        #expect(check.received(partner, .float(0.75), now: answered) == nil)
        #expect(check.received("/ch/12/mix/on", .int(1), now: answered) == nil)
    }
}

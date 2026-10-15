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
        #expect(check.received(partner, .float(0.25), arrivedAt: answered) == .none)
        #expect(check.deskCopies)
    }

    /// The desk stores a fader in 1024 steps: its copy of 0.25 can come back a hair off.
    @Test func roundingByTheDeskStillCounts() {
        var check = awaiting(.float(0.25))
        #expect(check.received(partner, .float(0.2502), arrivedAt: answered) == .none)
    }

    /// What a partner left behind means depends on the section, so the mirror decides; the check only reports it.
    /// The second wrong answer in a row decides: the first may be stale (see below).
    @Test func aPartnerLeftBehindReportsWhatItShouldHaveBeen() {
        var check = awaiting(.float(0.25))
        #expect(check.received(partner, .float(0.75), arrivedAt: answered) == .askAgain)
        check.rereadSent(partner, now: t0 + .milliseconds(300))
        #expect(check.received(partner, .float(0.75), arrivedAt: t0 + .milliseconds(350)) == .leftBehind(.float(0.25)))
        #expect(check.deskCopies)
    }

    /// A question asked just before the edit is answered with the old value, and on a busy main actor that answer
    /// can be handled after the re-read went out (CI, 2026-10-14). It must not split the pair: a second re-read,
    /// sent once every earlier question was answered, decides.
    @Test func aStaleAnswerAsksAgainInsteadOfJudging() {
        var check = awaiting(.float(0.25))
        #expect(check.received(partner, .float(0.75), arrivedAt: answered) == .askAgain, "stale: asked before the edit")
        #expect(check.received(partner, .float(0.25), arrivedAt: answered) == .none, "the first re-read's answer")
        check.rereadSent(partner, now: t0 + .milliseconds(300))
        #expect(check.received(partner, .float(0.25), arrivedAt: t0 + .milliseconds(350)) == .none)
    }

    /// Pushes during a drag carry older values; only the answer to the re-read is judged.
    @Test func pushesBeforeTheReReadAreIgnored() {
        var check = LinkCopyCheck()
        check.expect(partner, .float(0.25))
        #expect(check.received(partner, .float(0.1), arrivedAt: answered) == .none)
    }

    @Test func aLaterEditReplacesTheAwaitedValue() {
        var check = awaiting(.float(0.25))
        check.expect(partner, .float(0.5))
        #expect(check.received(partner, .float(0.4), arrivedAt: answered) == .none, "the old re-read's answer is no longer judged")
    }

    /// A lost answer must not make a later change on the desk look like a partner left behind: writing the old
    /// value then would undo the engineer's move.
    @Test func aMessageAfterTheWindowIsNotJudged() {
        var check = awaiting(.float(0.25))
        #expect(check.received(partner, .float(0.75), arrivedAt: t0 + .seconds(2)) == .none)
        #expect(check.received(partner, .float(0.75), arrivedAt: answered) == .none, "and it is forgotten")
    }

    /// After a lost connection the resync is the truth: nothing from before it is judged.
    @Test func forgetDropsEverythingAwaited() {
        var check = awaiting(.float(0.25))
        check.expect("/ch/12/mix/on", .int(0))
        check.forget()
        check.rereadSent("/ch/12/mix/on", now: t0)
        #expect(check.received(partner, .float(0.75), arrivedAt: answered) == .none)
        #expect(check.received("/ch/12/mix/on", .int(1), arrivedAt: answered) == .none)
    }
}

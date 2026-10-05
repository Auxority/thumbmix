import Testing

@testable import ThumbmixCore

/// Timing decisions driven with explicit instants: no sleeping, no dependence on runner speed.
struct LinkSupervisorTests {
    private let start = ContinuousClock.now

    private func supervisor() -> LinkSupervisor {
        LinkSupervisor(timing: .console, now: start)
    }

    @Test func freshLinkDoesNothing() {
        var supervisor = supervisor()
        #expect(
            supervisor.tick(now: start + .milliseconds(500), isLive: true, isLost: false)
                == LinkSupervisor.Actions())
    }

    @Test func quietConsoleIsProbedBeforeItIsLost() {
        var supervisor = supervisor()
        let actions = supervisor.tick(now: start + .milliseconds(1500), isLive: true, isLost: false)
        #expect(actions.probe)
        #expect(!actions.markLost)
    }

    @Test func silenceLongerThanLostAfterMarksLost() {
        var supervisor = supervisor()
        #expect(supervisor.tick(now: start + .milliseconds(3100), isLive: true, isLost: false).markLost)
    }

    @Test func hearingTheConsoleKeepsItLive() {
        var supervisor = supervisor()
        supervisor.heard(at: start + .seconds(2))
        #expect(
            !supervisor.tick(now: start + .milliseconds(3100), isLive: true, isLost: false).markLost)
    }

    @Test func stayingLostRebuildsTheSocketAfterTheInterval() {
        var supervisor = supervisor()
        let lostAt = start + .milliseconds(3100)
        #expect(supervisor.tick(now: lostAt, isLive: true, isLost: false).markLost)
        #expect(!supervisor.tick(now: lostAt + .seconds(4), isLive: false, isLost: true).restartSocket)
        #expect(supervisor.tick(now: lostAt + .seconds(5), isLive: false, isLost: true).restartSocket)
    }

    @Test func renewsOnSchedule() {
        var supervisor = supervisor()
        #expect(!supervisor.tick(now: start + .milliseconds(3900), isLive: true, isLost: false).renew)
        #expect(supervisor.tick(now: start + .seconds(4), isLive: true, isLost: false).renew)
        supervisor.renewed(at: start + .seconds(4))
        #expect(!supervisor.tick(now: start + .seconds(5), isLive: true, isLost: false).renew)
    }
}

struct EditHoldsTests {
    private let now = ContinuousClock.now
    private let hold = Duration.milliseconds(300)

    @Test func heldForTheWholeGestureHoweverLong() {
        var holds = EditHolds(hold: hold)
        holds.begin("/f")
        #expect(holds.isHeld("/f", now: now + .seconds(60)))
    }

    @Test func releaseHoldsBrieflyThenAsksForARereadOnce() {
        var holds = EditHolds(hold: hold)
        holds.begin("/f")
        holds.end("/f", now: now)
        #expect(holds.isHeld("/f", now: now + .milliseconds(299)))
        #expect(!holds.isHeld("/f", now: now + .milliseconds(301)))
        #expect(holds.takeDueRereads(now: now + .milliseconds(299)).isEmpty)
        #expect(holds.takeDueRereads(now: now + .milliseconds(301)) == ["/f"])
        #expect(holds.takeDueRereads(now: now + .seconds(1)).isEmpty)
    }

    @Test func aSetHoldsOnlyBriefly() {
        var holds = EditHolds(hold: hold)
        holds.edited("/f", now: now)
        #expect(holds.isHeld("/f", now: now + .milliseconds(100)))
        #expect(!holds.isHeld("/f", now: now + .milliseconds(400)))
    }

    @Test func resyncClearsTimedHoldsButNotActiveGestures() {
        var holds = EditHolds(hold: hold)
        holds.edited("/a", now: now)
        holds.begin("/b")
        holds.clearTimedHolds()
        #expect(!holds.isHeld("/a", now: now))
        #expect(holds.isHeld("/b", now: now))
    }
}

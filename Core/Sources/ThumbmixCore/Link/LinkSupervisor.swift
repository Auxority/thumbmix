/// The link's timing decisions as a pure function of the clock, so they can be tested with explicit
/// instants instead of sleeping. `ConsoleLink` calls `tick` on its loop and carries out the actions.
struct LinkSupervisor {
    struct Actions: Equatable {
        var markLost = false
        var restartSocket = false
        var probe = false
        var renew = false
    }

    let timing: LinkTiming
    private var lastHeard: ContinuousClock.Instant
    private var lastRenewal: ContinuousClock.Instant
    private var lastRestart: ContinuousClock.Instant

    init(timing: LinkTiming, now: ContinuousClock.Instant) {
        self.timing = timing
        lastHeard = now
        lastRenewal = now
        lastRestart = now
    }

    mutating func heard(at now: ContinuousClock.Instant) { lastHeard = now }
    mutating func renewed(at now: ContinuousClock.Instant) { lastRenewal = now }
    mutating func restarted(at now: ContinuousClock.Instant) { lastRestart = now }

    mutating func tick(now: ContinuousClock.Instant, isLive: Bool, isLost: Bool) -> Actions {
        var actions = Actions()
        let quiet = now - lastHeard
        if isLive, quiet > timing.lostAfter {
            actions.markLost = true
            // The restart interval counts from the moment the link was declared lost.
            lastRestart = now
        }
        if isLost, now - lastRestart >= timing.restartAfterLost { actions.restartSocket = true }
        // An idle console sends nothing, so ask for something before deciding it is gone.
        actions.probe = quiet > timing.probeWhenQuietFor
        actions.renew = now - lastRenewal >= timing.renewEvery
        return actions
    }
}

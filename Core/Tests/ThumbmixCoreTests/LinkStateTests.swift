import Testing

@testable import ThumbmixCore

/// What the mirror re-reads and forgets when links change, so a pair never shows a value the desk no longer has.
@MainActor
struct LinkStateTests {
    private let mirror = ConsoleMirror.preview()
    private var later: ContinuousClock.Instant { .now + .seconds(2) }

    /// The desk may copy the odd side's settings when a pair is linked, and may not push them.
    @Test func aLinkChangedOnTheDeskReReadsBothStrips() {
        mirror.apply(OSCMessage("/config/chlink/1-2", [.int(1)]))
        let due = Set(mirror.holds.takeDueRereads(now: later))
        #expect(due.contains("/ch/01/eq/1/g"))
        #expect(due.contains("/ch/02/eq/1/g"))
        #expect(due.contains("/ch/02/mix/pan"))
    }

    @Test func linkingFromTheAppReReadsBothStrips() {
        mirror.setLinked(StripID(.input, 3), true)
        let due = Set(mirror.holds.takeDueRereads(now: later))
        #expect(due.contains("/ch/04/dyn/thr"))
        #expect(due.contains("/ch/03/mix/pan"))
    }

    /// The audit re-reads the links all the time: only a change re-reads the strips.
    @Test func anUnchangedLinkReReadsNothing() {
        mirror.apply(OSCMessage("/config/chlink/9-10", [.int(1)]))
        #expect(mirror.holds.takeDueRereads(now: later).isEmpty)
    }

    /// Ticking the preference again on the desk ends "seen not linked"; the audit's unchanged re-read doesn't.
    @Test func aChangedPreferenceForgetsWhatWasSeen() {
        mirror.sectionsSeenUnlinked.insert(.eq)
        mirror.apply(OSCMessage(LinkSection.eq.preferenceAddress, [.int(1)]))
        #expect(mirror.sectionsSeenUnlinked.contains(.eq))
        mirror.apply(OSCMessage(LinkSection.eq.preferenceAddress, [.int(0)]))
        #expect(!mirror.sectionsSeenUnlinked.contains(.eq))
    }
}

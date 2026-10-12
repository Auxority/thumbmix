import Testing

@testable import ThumbmixCore

/// The reads after going live: an opened tab first, then the background fill, paced like the connect sync.
@MainActor
struct ReadQueueTests {
    private func queue(window: Int = 2, maxTries: Int = 3) -> ReadQueue {
        ReadQueue(window: window, timeout: .milliseconds(300), maxTries: maxTries)
    }

    @Test func keepsAWindowInFlight() {
        let reads = queue()
        reads.add(["/a", "/b", "/c"], urgent: false)
        let now = ContinuousClock.now
        #expect(reads.due(now: now) == ["/a", "/b"])
        #expect(reads.received("/a"))
        #expect(reads.due(now: now) == ["/c"])
    }

    @Test func anOpenedTabGoesAheadOfTheFill() {
        let reads = queue(window: 1)
        reads.add(["/fill1", "/fill2"], urgent: false)
        reads.add(["/tab"], urgent: true)
        #expect(reads.due(now: .now) == ["/tab"])
    }

    /// A tab opened while its values wait in the fill takes them along to the front.
    @Test func anUrgentAddressAlreadyQueuedMovesToTheFront() {
        let reads = queue(window: 1)
        reads.add(["/fill", "/tab"], urgent: false)
        reads.add(["/tab"], urgent: true)
        let now = ContinuousClock.now
        #expect(reads.due(now: now) == ["/tab"])
        #expect(reads.received("/tab"))
        #expect(reads.due(now: now) == ["/fill"])
        #expect(reads.received("/fill"))
        #expect(reads.due(now: now) == [], "asked once only")
    }

    @Test func anAddressInFlightIsNotAskedTwice() {
        let reads = queue()
        reads.add(["/a"], urgent: false)
        let now = ContinuousClock.now
        #expect(reads.due(now: now) == ["/a"])
        reads.add(["/a"], urgent: true)
        #expect(reads.due(now: now) == [])
    }

    @Test func reasksAfterTimeoutThenGivesUp() {
        let reads = queue(window: 8, maxTries: 2)
        reads.add(["/a"], urgent: true)
        let start = ContinuousClock.now
        #expect(reads.due(now: start) == ["/a"])
        #expect(reads.due(now: start + .milliseconds(400)) == ["/a"])
        #expect(reads.due(now: start + .milliseconds(800)) == [])
        #expect(reads.missing == ["/a"])
    }

    @Test func ignoresRepliesNotAskedFor() {
        #expect(!queue().received("/zzz"))
    }
}

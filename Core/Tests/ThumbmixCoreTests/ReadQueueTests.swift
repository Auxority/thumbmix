import Testing

@testable import ThumbmixCore

/// The reads after going live: an opened tab first, then the background fill, paced like the connect sync, which is
/// the overview added to this same queue.
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

    /// A linked pair's two Fed by tabs share their send sheets' taps and pans, read in one batch.
    @Test func anAddressTwiceInOneBatchIsAskedOnce() {
        for urgent in [false, true] {
            let reads = queue(window: 4)
            reads.add(["/a", "/b", "/a"], urgent: urgent)
            #expect(reads.due(now: .now) == ["/a", "/b"])
        }
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

    @Test func isIdleOnceEverythingWasAnsweredOrGivenUp() {
        let reads = queue(window: 2, maxTries: 2)
        reads.add(["/a", "/b", "/c"], urgent: false)
        let start = ContinuousClock.now
        _ = reads.due(now: start)
        #expect(reads.received("/a"))
        #expect(!reads.isIdle)
        #expect(reads.due(now: start) == ["/c"])
        #expect(reads.received("/b"))
        #expect(reads.received("/c"))
        #expect(reads.isIdle)
    }

    @Test func givingUpMakesTheQueueIdle() {
        let reads = queue(window: 8, maxTries: 2)
        reads.add(["/a"], urgent: false)
        let start = ContinuousClock.now
        _ = reads.due(now: start)
        _ = reads.due(now: start + .milliseconds(400))
        #expect(!reads.isIdle)
        _ = reads.due(now: start + .milliseconds(800))
        #expect(reads.isIdle)
    }

    @Test func answeredCountsOnlyAskedAddresses() {
        let reads = queue(window: 8)
        reads.add(["/a", "/b"], urgent: false)
        _ = reads.due(now: .now)
        _ = reads.received("/zzz")
        #expect(reads.answered == 0)
        _ = reads.received("/a")
        #expect(reads.answered == 1)
    }

    @Test func defaultRetriesOutlastAShortWiFiDrop() {
        let reads = ReadQueue()
        reads.add(["/a"], urgent: false)
        var now = ContinuousClock.now
        _ = reads.due(now: now)
        for _ in 1...5 {
            now += .milliseconds(400)
            #expect(reads.due(now: now) == ["/a"])
        }
        #expect(reads.received("/a"))
        #expect(reads.isIdle)
        #expect(reads.missing.isEmpty)
    }
}

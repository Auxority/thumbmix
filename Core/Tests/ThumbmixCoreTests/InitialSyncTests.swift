import Testing

@testable import ThumbmixCore

@MainActor
struct InitialSyncTests {
    @Test func keepsAWindowInFlight() {
        let sync = InitialSync(
            addresses: ["/a", "/b", "/c"], window: 2, timeout: .milliseconds(300), maxTries: 3)
        let now = ContinuousClock.now
        #expect(sync.due(now: now) == ["/a", "/b"])
        sync.received("/a")
        #expect(sync.due(now: now) == ["/c"])
        #expect(!sync.isDone)
    }

    @Test func reasksAfterTimeoutThenGivesUp() {
        let sync = InitialSync(addresses: ["/a"], window: 8, timeout: .milliseconds(300), maxTries: 2)
        let start = ContinuousClock.now
        #expect(sync.due(now: start) == ["/a"])
        #expect(sync.due(now: start + .milliseconds(400)) == ["/a"])
        #expect(sync.due(now: start + .milliseconds(800)) == [])
        #expect(sync.isDone)
        #expect(sync.missing == ["/a"])
    }

    @Test func progressCountsAnswered() {
        let sync = InitialSync(
            addresses: ["/a", "/b"], window: 8, timeout: .milliseconds(300), maxTries: 3)
        _ = sync.due(now: .now)
        sync.received("/a")
        #expect(sync.progress == 0.5)
    }

    @Test func defaultRetriesOutlastAShortWiFiDrop() {
        let sync = InitialSync(addresses: ["/a"])
        var now = ContinuousClock.now
        _ = sync.due(now: now)
        for _ in 1...5 {
            now += .milliseconds(400)
            #expect(sync.due(now: now) == ["/a"])
        }
        sync.received("/a")
        #expect(sync.isDone)
        #expect(sync.missing.isEmpty)
    }

    @Test func ignoresRepliesNotAskedFor() {
        let sync = InitialSync(addresses: ["/a"], window: 8, timeout: .milliseconds(300), maxTries: 3)
        sync.received("/zzz")
        #expect(sync.progress == 0)
    }
}

import FakeM32
import Testing

@testable import ThumbmixCore

@MainActor
struct OverviewListTests {
    /// During a sync each arriving value would rebuild the overview (~0.5 s per connect, 2026-10-24): it holds the list
    /// last read live, unchanged, and reading it watches no cell.
    @Test func holdsStillWhileNotLive() async throws {
        try await withLiveDesk { _, mirror in
            let inputs = StripID.all(.input)
            #expect(mirror.cell(Self.link12).argument == .int(0), "ch 1-2 start unlinked")
            let live = mirror.overviewList(inputs, showUnused: true)
            mirror.status = .syncing(0)
            let changes = Changes(mirror) { _ = $0.overviewList(inputs, showUnused: true) }

            mirror.apply(OSCMessage(Self.link12, [.int(1)]))
            #expect(changes.count == 0, "a value arriving mid-sync")
            #expect(mirror.overviewList(inputs, showUnused: true) == live, "held")
            mirror.status = .live
            #expect(changes.count == 1, "going live")
            #expect(mirror.overviewList(inputs, showUnused: true) != live, "read again once live")
        }
    }

    /// While live the list follows the desk: a link made on it regroups the rows.
    @Test func followsTheDeskWhileLive() async throws {
        try await withLiveDesk { _, mirror in
            let inputs = StripID.all(.input)
            let before = mirror.overviewList(inputs, showUnused: true)
            let changes = Changes(mirror) { _ = $0.overviewList(inputs, showUnused: true) }

            mirror.apply(OSCMessage(Self.link12, [.int(1)]))
            #expect(changes.count == 1)
            #expect(mirror.overviewList(inputs, showUnused: true) != before)
        }
    }

    /// A new desk has no list to hold: none until it is live.
    @Test func aFirstConnectShowsNoneUntilLive() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        mirror.status = .syncing(0.5)
        #expect(mirror.overviewList(StripID.all(.input), showUnused: true) == OverviewList(items: [], unused: []))
        mirror.status = .live
        #expect(!mirror.overviewList(StripID.all(.input), showUnused: true).items.isEmpty)
    }

    private static let link12 = "/config/chlink/1-2"

    /// A resync rewrites every overview cell, nearly all with the value they hold, and the held list's rows must not
    /// redraw for those. Observation already skips an equal value; this pins it.
    @Test func anUnchangedReplyNotifiesNoOne() async throws {
        try await withLiveDesk { _, mirror in
            let name = "/ch/01/config/name"
            let held = try #require(mirror.cell(name).argument)
            let changes = Changes(mirror) { _ = $0.cell(name).argument }

            mirror.apply(OSCMessage(name, [held]))
            #expect(changes.count == 0, "same value")
            mirror.apply(OSCMessage(name, [.string("Kick 2")]))
            #expect(changes.count == 1, "new value")
        }
    }
}

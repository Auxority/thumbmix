import FakeM32
import Observation
import Testing

@testable import ThumbmixCore

@MainActor
struct ConsoleMirrorTests {
    private func liveMirror(_ port: UInt16) async -> ConsoleMirror {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port, timing: .fast))
        mirror.start()
        _ = await eventually(timeout: syncTimeout) { mirror.isLive }
        return mirror
    }

    /// The banner shows each percent of the sync; a screen that only dims until live, or the root that watches for a
    /// failure, must not redraw for each one (it cost the overview ~1 s per sync, 2026-10-23).
    @Test func syncProgressNotifiesOnlyStatusReaders() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        mirror.status = .syncing(0)
        let isLive = Changes(mirror) { _ = $0.isLive }
        let failure = Changes(mirror) { _ = $0.failure }

        mirror.status = .syncing(0.5)
        #expect(isLive.count == 0, "progress")
        #expect(failure.count == 0, "progress")
        mirror.status = .live
        #expect(isLive.count == 1, "live")
        mirror.status = .lost
        #expect(isLive.count == 2 && !mirror.isLive, "lost")
        mirror.status = .failed(.noReply)
        #expect(failure.count == 1 && mirror.failure == .noReply, "failed")
        mirror.status = .connecting
        #expect(failure.count == 2 && mirror.failure == nil, "connecting again")
    }

    @Test func syncFillsTheOverview() async throws {
        try await withLiveDesk { fake, mirror in
            #expect(mirror.isLive)
            #expect(mirror.cell("/ch/01/config/name").argument == .string("Kick"))
            #expect(Catalog.overviewAddresses().allSatisfy { mirror.cell($0).argument != nil })
        }
    }

    /// "Live" must mean every overview value is in: the overview builds its rows when the status turns live, and a
    /// Link Preference still unread then split a linked pair into two rows (2026-10-12). The last answer is the
    /// preference, so the status change is checked as it happens.
    @Test func everyOverviewValueIsStoredBeforeGoingLive() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let overview = ["/ch/01/config/name", "/config/linkcfg/fdrmute"]
        let mirror = ConsoleMirror(
            link: ConsoleLink(host: "127.0.0.1", port: port, timing: .fast), overview: overview, auditAddresses: [])
        let watch = UnreadAtStatusChange(mirror, overview)
        mirror.start()
        defer { mirror.stop() }

        #expect(await eventually(timeout: syncTimeout) { mirror.isLive })
        #expect(watch.unread == [], "unread as the status turned live")
    }

    /// UI tests wait for this before trusting the screen: until then it can still show the previous test's desk.
    @Test func fakeKnowsWhenTheAppReachedIt() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        #expect(!fake.hasClients)
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port))
        mirror.start()
        defer { mirror.stop() }

        #expect(await eventually { fake.hasClients })
    }

    @Test func syncSurvivesLostReplies() async throws {
        try await withLiveDesk(dropsGets: 40) { fake, mirror in
            #expect(mirror.isLive)
            #expect(Catalog.overviewAddresses().allSatisfy { mirror.cell($0).argument != nil })
        }
    }

    @Test func deskChangesArriveAfterSync() async throws {
        try await withLiveDesk { fake, mirror in
            fake.deskChange("/ch/02/mix/fader", .float(0.5))

            #expect(await eventually { mirror.cell("/ch/02/mix/fader").argument == .float(0.5) })
        }
    }

    @Test func editsReachTheConsole() async throws {
        try await withLiveDesk { fake, mirror in
            mirror.set("/ch/01/mix/fader", .float(0.6))

            #expect(mirror.cell("/ch/01/mix/fader").argument == .float(0.6))
            #expect(await eventually { fake.value(at: "/ch/01/mix/fader") == .float(0.6) })
        }
    }

    @Test func editsBySpecGoThroughTheSpecsScale() async throws {
        try await withLiveDesk { _, mirror in
            let fader = Catalog.fader(StripID(.input, 1))
            mirror.set(fader, normalized: 0.6)
            #expect(mirror.cell(fader.address).argument == fader.scale.argument(fromNormalized: 0.6))

            mirror.set(fader, value: 0)
            let unity = fader.scale.argument(fromNormalized: fader.scale.normalized(forValue: 0))
            #expect(mirror.cell(fader.address).argument == unity)
        }
    }

    @Test func editsIgnoredWhileNotLive() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9, timing: .fast))
        mirror.set("/ch/01/mix/fader", .float(0.6))
        #expect(mirror.cell("/ch/01/mix/fader").argument == nil)
    }

    @Test func unknownAddressIgnored() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9, timing: .fast))
        mirror.apply(OSCMessage("/nope", [.int(1)]))
        mirror.apply(OSCMessage("node", [.string("/ch/01/mix ON\n")]))
        mirror.apply(OSCMessage("/meters/1", [.string("not a blob")]))
        #expect(mirror.cells["/nope"] == nil)
    }

    @Test func metersFillCells() async throws {
        try await withLiveDesk(meters: true) { fake, mirror in
            #expect(await eventually { mirror.meter(StripID(.input, 1)).level > 0 })
            #expect(await eventually { mirror.meter(StripID(.input, 1)).gateGain < 1 })
        }
    }

    @Test func badFloatsAreDroppedOrClamped() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9, timing: .fast))
        mirror.apply(OSCMessage("/ch/01/mix/pan", [.float(0.5)]))
        mirror.apply(OSCMessage("/ch/01/mix/pan", [.float(.nan)]))
        #expect(mirror.cell("/ch/01/mix/pan").argument == .float(0.5))
        mirror.apply(OSCMessage("/ch/01/mix/pan", [.float(1.7)]))
        #expect(mirror.cell("/ch/01/mix/pan").argument == .float(1))
    }

    @Test func goesLiveWithoutAnUnansweredAddressAndIgnoresEditsToIt() async throws {
        var state = DemoState.values()
        state["/ch/02/mix/fader"] = nil
        let fake = try FakeM32(state: state, streamsMeters: false)
        let port = try await fake.start()
        defer { fake.stop() }
        let mirror = await liveMirror(port)
        defer { mirror.stop() }

        #expect(mirror.isLive)
        #expect(mirror.cell("/ch/02/mix/fader").argument == nil)
        mirror.set("/ch/02/mix/fader", .float(0.6))
        try await Task.sleep(for: .milliseconds(200))
        #expect(mirror.cell("/ch/02/mix/fader").argument == nil)
        #expect(!fake.receivedSets.contains { $0.address == "/ch/02/mix/fader" })
    }

    @Test func holdLastsForTheWholeGesture() async throws {
        try await withLiveDesk { fake, mirror in
            let fader = "/ch/01/mix/fader"

            mirror.beginEdit(fader)
            mirror.set(fader, .float(0.6))
            try await Task.sleep(for: .milliseconds(450))
            fake.deskChange(fader, .float(0.1))
            try await Task.sleep(for: .milliseconds(100))

            #expect(mirror.cell(fader).argument == .float(0.6))
            mirror.endEdit(fader)
        }
    }

    @Test func consoleValueShowsAfterRelease() async throws {
        try await withLiveDesk { fake, mirror in
            let fader = "/ch/01/mix/fader"

            mirror.beginEdit(fader)
            mirror.set(fader, .float(0.6))
            // The desk's change must come after the app's set: a set still in flight on a busy CI runner would land
            // last and leave 0.6 on the desk.
            #expect(await eventually { fake.value(at: fader) == .float(0.6) }, "the app's set reached the desk")
            fake.deskChange(fader, .float(0.1))
            try await Task.sleep(for: .milliseconds(50))
            mirror.endEdit(fader)

            #expect(await eventually { mirror.cell(fader).argument == .float(0.1) })
        }
    }

    @Test func auditCorrectsChangesThatWereNeverPushed() async throws {
        try await withLiveDesk(
            auditAddresses: ["/ch/02/mix/fader"], before: { $0.ignoresXremote = true },
            body: { fake, mirror in
                fake.deskChange("/ch/02/mix/fader", .float(0.5))

                #expect(await eventually { mirror.cell("/ch/02/mix/fader").argument == .float(0.5) })
            })
    }

    @Test func wakeResyncs() async throws {
        try await withLiveDesk { fake, mirror in
            mirror.wake()

            #expect(mirror.status == .lost)
            #expect(await eventually(timeout: syncTimeout) { mirror.isLive })
        }
    }

    @Test func lostThenResyncs() async throws {
        try await withLiveDesk { fake, mirror in
            fake.silent = true
            #expect(await eventually { mirror.status == .lost })
            #expect(!mirror.isLive)

            fake.silent = false
            #expect(await eventually(timeout: syncTimeout) { mirror.isLive })
        }
    }
}

/// Which of `addresses` were unread each time the mirror's status changed, taken as it changed: what a screen
/// rebuilding on that change could see.
@MainActor
private final class UnreadAtStatusChange {
    private(set) var unread: [String]?
    private let mirror: ConsoleMirror
    private let addresses: [String]

    init(_ mirror: ConsoleMirror, _ addresses: [String]) {
        self.mirror = mirror
        self.addresses = addresses
        watch()
    }

    private func watch() {
        withObservationTracking {
            _ = mirror.status
        } onChange: { [weak self] in
            MainActor.assumeIsolated { self?.record() }
        }
    }

    private func record() {
        unread = addresses.filter { mirror.cell($0).argument == nil }
        watch()
    }
}

/// Counts the changes a view reading only `read` would redraw for.
@MainActor
private final class Changes {
    private(set) var count = 0
    private let mirror: ConsoleMirror
    private let read: (ConsoleMirror) -> Void

    init(_ mirror: ConsoleMirror, _ read: @escaping (ConsoleMirror) -> Void) {
        self.mirror = mirror
        self.read = read
        watch()
    }

    private func watch() {
        withObservationTracking {
            read(mirror)
        } onChange: { [weak self] in
            MainActor.assumeIsolated { self?.record() }
        }
    }

    private func record() {
        count += 1
        watch()
    }
}

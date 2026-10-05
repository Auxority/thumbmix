import FakeM32
import Testing
@testable import ThumbmixCore

@MainActor
struct ConsoleMirrorTests {
    private func liveMirror(_ fake: FakeM32, _ port: UInt16) async -> ConsoleMirror {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port, timing: .fast))
        mirror.start()
        _ = await eventually(timeout: .seconds(10)) { mirror.isLive }
        return mirror
    }

    @Test func syncFillsEveryCell() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }

        #expect(mirror.isLive)
        #expect(mirror.cell("/ch/01/config/name").argument == .string("Kick"))
        #expect(Catalog.syncAddresses().allSatisfy { mirror.cell($0).argument != nil })
    }

    @Test func syncSurvivesLostReplies() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        fake.dropNextGets(40)
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }

        #expect(mirror.isLive)
        #expect(Catalog.syncAddresses().allSatisfy { mirror.cell($0).argument != nil })
    }

    @Test func deskChangesArriveAfterSync() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }

        fake.deskChange("/ch/02/mix/fader", .float(0.5))

        #expect(await eventually { mirror.cell("/ch/02/mix/fader").argument == .float(0.5) })
    }

    @Test func editsReachTheConsole() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }

        mirror.set("/ch/01/mix/fader", .float(0.6))

        #expect(mirror.cell("/ch/01/mix/fader").argument == .float(0.6))
        #expect(await eventually { fake.value(at: "/ch/01/mix/fader") == .float(0.6) })
    }

    @Test func localEditHoldsAgainstPushes() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }

        mirror.set("/ch/01/mix/fader", .float(0.6))
        fake.deskChange("/ch/01/mix/fader", .float(0.1))
        try await Task.sleep(for: .milliseconds(100))

        #expect(mirror.cell("/ch/01/mix/fader").argument == .float(0.6))
        #expect(await eventually { fake.value(at: "/ch/01/mix/fader") == .float(0.6) })
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
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }

        #expect(await eventually { mirror.meter(StripID(.input, 1)).level > 0 })
        #expect(await eventually { mirror.meter(StripID(.input, 1)).gateGain < 1 })
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
        var state = FakeState.demo()
        state["/ch/02/mix/fader"] = nil
        let fake = try FakeM32(state: state)
        let port = try await fake.start()
        defer { fake.stop() }
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }

        #expect(mirror.isLive)
        #expect(mirror.cell("/ch/02/mix/fader").argument == nil)
        mirror.set("/ch/02/mix/fader", .float(0.6))
        try await Task.sleep(for: .milliseconds(200))
        #expect(mirror.cell("/ch/02/mix/fader").argument == nil)
        #expect(!fake.receivedSets.contains { $0.address == "/ch/02/mix/fader" })
    }

    @Test func holdLastsForTheWholeGesture() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }
        let fader = "/ch/01/mix/fader"

        mirror.beginEdit(fader)
        mirror.set(fader, .float(0.6))
        try await Task.sleep(for: .milliseconds(450))
        fake.deskChange(fader, .float(0.1))
        try await Task.sleep(for: .milliseconds(100))

        #expect(mirror.cell(fader).argument == .float(0.6))
        mirror.endEdit(fader)
    }

    @Test func consoleValueShowsAfterRelease() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }
        let fader = "/ch/01/mix/fader"

        mirror.beginEdit(fader)
        mirror.set(fader, .float(0.6))
        try await Task.sleep(for: .milliseconds(100))
        fake.deskChange(fader, .float(0.1))
        try await Task.sleep(for: .milliseconds(50))
        mirror.endEdit(fader)

        #expect(await eventually { mirror.cell(fader).argument == .float(0.1) })
    }

    @Test func auditCorrectsChangesThatWereNeverPushed() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        fake.ignoresXremote = true
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port, timing: .fast), auditAddresses: ["/ch/02/mix/fader"])
        mirror.start()
        defer { mirror.stop() }
        #expect(await eventually(timeout: .seconds(10)) { mirror.isLive })

        fake.deskChange("/ch/02/mix/fader", .float(0.5))

        #expect(await eventually { mirror.cell("/ch/02/mix/fader").argument == .float(0.5) })
    }

    @Test func wakeResyncs() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }

        mirror.wake()

        #expect(mirror.status == .lost)
        #expect(await eventually(timeout: .seconds(10)) { mirror.isLive })
    }

    @Test func lostThenResyncs() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(fake, port)
        defer { mirror.stop() }

        fake.silent = true
        #expect(await eventually { mirror.status == .lost })
        #expect(!mirror.isLive)

        fake.silent = false
        #expect(await eventually(timeout: .seconds(10)) { mirror.isLive })
    }
}

import FakeM32
import Testing

@testable import ThumbmixCore

/// Short enough to keep the suite quick, with margins wide enough for a slow CI runner.
/// Exact timing rules are tested deterministically in TimingDecisionTests.
extension LinkTiming {
    static let fast = LinkTiming(
        identifyTimeout: .seconds(2), tick: .milliseconds(50),
        renewEvery: .milliseconds(500), probeWhenQuietFor: .milliseconds(250), lostAfter: .seconds(1),
        restartAfterLost: .seconds(1)
    )
}

@MainActor
struct ConsoleLinkTests {
    @Test func identifiesAnM32() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let link = ConsoleLink(host: "127.0.0.1", port: port, timing: .fast)
        defer { link.stop() }

        link.start()

        #expect(await eventually { link.state == .live(ConsoleInfo(model: "M32", firmware: "4.06")) })
    }

    @Test func rejectsAnX32() async throws {
        let (fake, port) = try await startFake(model: "X32")
        defer { fake.stop() }
        let link = ConsoleLink(host: "127.0.0.1", port: port, timing: .fast)
        defer { link.stop() }

        link.start()

        #expect(await eventually { link.state == .failed(.notAnM32(model: "X32")) })
    }

    @Test func silentConsoleIsNoReply() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        fake.silent = true
        let link = ConsoleLink(host: "127.0.0.1", port: port, timing: .fast)
        defer { link.stop() }

        link.start()

        #expect(await eventually { link.state == .failed(.noReply) })
    }

    @Test func silenceMakesLinkLostThenLiveAgain() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let link = ConsoleLink(host: "127.0.0.1", port: port, timing: .fast)
        defer { link.stop() }
        link.start()
        #expect(await eventually { if case .live = link.state { true } else { false } })

        fake.silent = true
        #expect(await eventually { link.state == .lost })

        fake.silent = false
        #expect(await eventually { if case .live = link.state { true } else { false } })
    }

    @Test func pushedChangesReachOnMessage() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let link = ConsoleLink(host: "127.0.0.1", port: port, timing: .fast)
        defer { link.stop() }
        var received: [OSCMessage] = []
        link.onMessage = { received.append($0) }
        link.start()
        #expect(await eventually { if case .live = link.state { true } else { false } })
        try await Task.sleep(for: .milliseconds(100))

        fake.deskChange("/ch/03/mix/on", .int(0))

        #expect(await eventually { received.contains(OSCMessage("/ch/03/mix/on", [.int(0)])) })
        #expect(!received.contains { $0.address == "/info" })
    }

    @Test func twoRenewalsFitInsideTheConsoleExpiry() {
        // /xremote and /meters expire after 10 s; one lost renewal must not lapse them.
        #expect(LinkTiming.console.renewEvery * 2 < .seconds(10))
    }

    @Test func stayingLostRebuildsTheSocket() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let link = ConsoleLink(host: "127.0.0.1", port: port, timing: .fast)
        defer { link.stop() }
        link.start()
        #expect(await eventually { if case .live = link.state { true } else { false } })

        fake.silent = true
        #expect(await eventually { link.state == .lost })
        #expect(await eventually { link.transportGeneration > 0 })

        fake.silent = false
        #expect(await eventually { if case .live = link.state { true } else { false } })
    }

    @Test func wakeMarksLostUntilTheConsoleAnswersAgain() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let link = ConsoleLink(host: "127.0.0.1", port: port, timing: .fast)
        defer { link.stop() }
        link.start()
        #expect(await eventually { if case .live = link.state { true } else { false } })
        let generation = link.transportGeneration

        link.wake()

        #expect(link.state == .lost)
        #expect(link.transportGeneration == generation + 1)
        #expect(await eventually { if case .live = link.state { true } else { false } })
    }

    /// The mirror stops a link that found no M32; coming back from the background must not revive it.
    @Test func wakeLeavesAStoppedLinkStopped() async throws {
        let (fake, port) = try await startFake(model: "X32")
        defer { fake.stop() }
        let link = ConsoleLink(host: "127.0.0.1", port: port, timing: .fast)
        link.start()
        #expect(await eventually { link.state == .failed(.notAnM32(model: "X32")) })
        link.stop()
        let generation = link.transportGeneration

        link.wake()

        #expect(link.transportGeneration == generation)
        #expect(link.state == .failed(.notAnM32(model: "X32")))
    }
}

import FakeM32
import Foundation
import Testing

@testable import ThumbmixCore

@MainActor
struct TransportTests {
    @Test func infoRoundTripsThroughFake() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let transport = UDPTransport(host: "127.0.0.1", port: port)
        transport.start()
        defer { transport.cancel() }
        let recorder = MessageRecorder(transport.messages)

        // UDP may drop one datagram, and a busy CI runner can take longer than one wait: ask again, like the
        // app's sync does. A single /info with a 2 s wait failed on CI under load (PR #33's run).
        var reply: OSCMessage?
        for _ in 1...5 where reply == nil {
            transport.send(OSCMessage("/info"))
            reply = await recorder.wait(for: "/info")
        }
        #expect(reply?.string(at: 2) == "M32")
    }

    /// The link check judges a reply's age (`LinkCopyCheck.answerWindow`): one that came in while the main actor was
    /// busy must not look as old as the wait to read it.
    @Test(.timeLimit(.minutes(1))) func aReplyIsTimedWhenItArrivesNotWhenItIsRead() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let transport = UDPTransport(host: "127.0.0.1", port: port)
        transport.start()
        defer { transport.cancel() }
        var arrivals = transport.messages.makeAsyncIterator()

        // A few asks, so a dropped datagram can't leave the wait below hanging.
        for _ in 1...3 { transport.send(OSCMessage("/info")) }
        let asked = ContinuousClock.now
        blockTheMainActor(for: 0.5)  // busy while the replies come in

        let arrival = try #require(await arrivals.next())
        #expect(arrival.time - asked < .milliseconds(250))
    }

    /// m32-probe times meter changes from the recorder (section 15), so it keeps the transport's arrival time.
    @Test(.timeLimit(.minutes(1))) func theRecorderKeepsWhenEachMessageArrived() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let transport = UDPTransport(host: "127.0.0.1", port: port)
        transport.start()
        defer { transport.cancel() }
        let recorder = MessageRecorder(transport.messages)

        for _ in 1...3 { transport.send(OSCMessage("/info")) }
        let asked = ContinuousClock.now
        blockTheMainActor(for: 0.5)  // the recorder runs on the main actor: it records only after this

        _ = await recorder.wait(for: "/info")
        let arrival = try #require(recorder.arrivals.first)
        #expect(arrival.message.address == "/info")
        #expect(arrival.time - asked < .milliseconds(250))
    }

    /// Blocks, rather than suspends, so nothing else runs on the main actor meanwhile.
    private func blockTheMainActor(for seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @Test func xremotePushesChangesFromOtherClients() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let listener = UDPTransport(host: "127.0.0.1", port: port)
        let mover = UDPTransport(host: "127.0.0.1", port: port)
        listener.start()
        mover.start()
        defer {
            listener.cancel()
            mover.cancel()
        }
        let recorder = MessageRecorder(listener.messages)

        listener.send(OSCMessage("/xremote"))
        try await Task.sleep(for: .milliseconds(100))
        mover.send(OSCMessage("/ch/01/mix/fader", [.float(0.25)]))

        let pushed = await recorder.wait(for: "/ch/01/mix/fader")
        #expect(pushed?.arguments == [.float(0.25)])
        #expect(fake.value(at: "/ch/01/mix/fader") == .float(0.25))
    }

    @Test func metersStreamAsBlobs() async throws {
        let (fake, port) = try await startFake(meters: true)
        defer { fake.stop() }
        let transport = UDPTransport(host: "127.0.0.1", port: port)
        transport.start()
        defer { transport.cancel() }
        let recorder = MessageRecorder(transport.messages)

        // Asked again like /info above: one request with one 2 s wait failed on CI under load (PR #60's run).
        var reply: OSCMessage?
        for _ in 1...5 where reply == nil {
            transport.send(OSCMessage("/meters", [.string("/meters/1")]))
            reply = await recorder.wait(for: "/meters/1")
        }
        guard case .blob(let blob)? = reply?.arguments.first else {
            Issue.record("no meter blob")
            return
        }
        #expect(MeterBlob.floats(from: blob).count == 96)
    }

    /// ~80 parallel fakes streaming meters at the desk's rate took most of a CI runner's CPU, so syncs missed their
    /// deadline (2026-10-19); Core tests stream meters only where they read them.
    @Test func aFakeWithoutMetersSendsNoneEvenWhenSubscribed() async throws {
        let fake = try FakeM32(streamsMeters: false)
        let port = try await fake.start()
        defer { fake.stop() }
        let transport = UDPTransport(host: "127.0.0.1", port: port)
        transport.start()
        defer { transport.cancel() }
        let recorder = MessageRecorder(transport.messages)

        var reply: OSCMessage?
        for _ in 1...5 where reply == nil {
            transport.send(OSCMessage("/meters", [.string("/meters/1")]))
            transport.send(OSCMessage("/info"))
            reply = await recorder.wait(for: "/info")
        }
        #expect(reply != nil, "the fake is up and answering")
        try await Task.sleep(for: .milliseconds(200))  // four meter ticks
        #expect(recorder.last(address: "/meters/1") == nil)
    }
}

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
        let (fake, port) = try await startFake()
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
}

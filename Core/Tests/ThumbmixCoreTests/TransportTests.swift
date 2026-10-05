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

        transport.send(OSCMessage("/info"))

        let reply = await recorder.wait(for: "/info")
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

        transport.send(OSCMessage("/meters", [.string("/meters/1")]))

        let reply = await recorder.wait(for: "/meters/1")
        guard case .blob(let blob)? = reply?.arguments.first else {
            Issue.record("no meter blob")
            return
        }
        #expect(MeterBlob.floats(from: blob).count == 96)
    }
}

import FakeM32
import Foundation
import Observation
import Testing

@testable import ThumbmixCore

struct DecibelAmountTests {
    @Test func amountsReadWithoutASign() {
        let strip = StripID(.input, 1)
        #expect(ValueText.format(0.5, Catalog.gate(strip).range, locale: .testEnglish) == "31.5 dB")
        #expect(
            ValueText.format(0.5, Catalog.dynamics(strip).makeup, locale: .testEnglish) == "12.0 dB")
        #expect(ValueText.format(1, Catalog.trim(strip), locale: .testEnglish) == "+18.0 dB")
    }
}

struct ConsoleAddressTests {
    @Test(arguments: ["0.0.0.0", "0.1.2.3", "255.255.255.255", "224.0.0.1", "239.1.2.3", "240.0.0.1"])
    func nonUnicastIsRejected(_ host: String) {
        #expect(!Discovery.isUsableIPv4(host))
    }

    @Test func loopbackStaysAllowedForTheFake() {
        #expect(Discovery.isUsableIPv4("127.0.0.1"))
    }
}

/// Set from a @Sendable observation callback; only read after the callback could have run.
private final class Flag: @unchecked Sendable {
    var raised = false
}

@MainActor
struct MirrorRobustnessTests {
    @Test func wrongTypeReplyKeepsTheKnownValue() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        mirror.apply(OSCMessage("/ch/01/mix/fader", [.float(0.5)]))
        mirror.apply(OSCMessage("/ch/01/mix/fader", [.int(1)]))
        #expect(mirror.cell("/ch/01/mix/fader").argument == .float(0.5))
    }

    @Test func unchangedMeterValuesDoNotRedraw() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        let blob = OSCMessage("/meters/1", [.blob(MeterBlob.encode(Array(repeating: 0.5, count: 96)))])
        mirror.apply(blob)
        let changed = Flag()
        withObservationTracking {
            _ = mirror.meter(StripID(.input, 1)).level
        } onChange: {
            changed.raised = true
        }

        mirror.apply(blob)
        #expect(!changed.raised)

        // Control: a real change must still notify, or the check above proves nothing.
        mirror.apply(
            OSCMessage("/meters/1", [.blob(MeterBlob.encode(Array(repeating: 0.25, count: 96)))]))
        #expect(changed.raised)
    }

    @Test func failedLinkStopsRunning() async throws {
        let (fake, port) = try await startFake(model: "X32")
        defer { fake.stop() }
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port, timing: .fast))
        mirror.start()

        #expect(await eventually { mirror.status == .failed(.notAnM32(model: "X32")) })
        #expect(!mirror.isRunning)
    }

    @Test func resyncDropsHoldsFromBeforeTheOutage() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = ConsoleMirror(
            link: ConsoleLink(host: "127.0.0.1", port: port, timing: .fast), auditAddresses: [])
        mirror.start()
        defer { mirror.stop() }
        #expect(await eventually(timeout: .seconds(10)) { mirror.isLive })
        let fader = "/ch/01/mix/fader"
        let consoleValue = fake.value(at: fader)

        fake.silent = true
        mirror.set(fader, .float(0.6))
        // Stay silent past the 20 ms send tick so the set is really lost, as in a Wi-Fi dropout.
        try await Task.sleep(for: .milliseconds(100))
        mirror.wake()
        fake.silent = false

        #expect(await eventually(timeout: .seconds(10)) { mirror.isLive })
        #expect(mirror.cell(fader).argument == consoleValue)
    }
}

@MainActor
struct LinkRobustnessTests {
    @Test func stopBeforeIdentifyFinishesChangesNothing() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let link = ConsoleLink(host: "127.0.0.1", port: port, timing: .fast)

        link.start()
        link.stop()
        try await Task.sleep(for: .milliseconds(200))

        #expect(link.state == .connecting)
    }
}

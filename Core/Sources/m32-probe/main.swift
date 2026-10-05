import Foundation
import ThumbmixCore

// Read-only: answers SPEC.md section 9 on the real console. Sends gets, /xremote and /meters, never a set.
guard let host = CommandLine.arguments.dropFirst().first else {
    print("usage: swift run --package-path Core m32-probe <console-ip>")
    exit(2)
}

let transport = UDPTransport(host: host, port: 10023)
transport.start()
let recorder = MessageRecorder(transport.messages)

func describe(_ message: OSCMessage) -> String {
    let arguments = message.arguments.map { argument -> String in
        switch argument {
        case .int(let value): "i:\(value)"
        case .float(let value): "f:\(value)"
        case .string(let value): "s:\"\(value)\""
        case .blob(let value): "b:\(value.count) bytes"
        }
    }
    return ([message.address] + arguments).joined(separator: " ")
}

@MainActor
func ask(_ address: String) async -> OSCMessage? {
    for _ in 1...3 {
        recorder.clear()
        transport.send(OSCMessage(address))
        if let reply = await recorder.wait(for: address, timeout: .milliseconds(500)) { return reply }
    }
    return nil
}

func zeroPadded(_ text: String, to width: Int) -> String {
    String(repeating: "0", count: max(0, width - text.count)) + text
}

print("== 1. Identity")
for address in ["/info", "/xinfo", "/status"] {
    print(await ask(address).map(describe) ?? "\(address) NO REPLY")
}

print("\n== 2. Push test: keep the Mixing Station clients connected.")
print("Move any fader on the desk or in Mixing Station during the next 20 seconds...")
recorder.clear()
transport.send(OSCMessage("/xremote"))
let pushStart = ContinuousClock.now
var renewed = false
while ContinuousClock.now - pushStart < .seconds(20) {
    if !renewed, ContinuousClock.now - pushStart > .seconds(9) {
        transport.send(OSCMessage("/xremote"))
        renewed = true
    }
    try? await Task.sleep(for: .milliseconds(200))
}
let pushes = recorder.messages
print("pushed messages received: \(pushes.count)")
for push in pushes.prefix(10) { print("  " + describe(push)) }
print(
    pushes.isEmpty
        ? "RESULT: NO pushes. The /xremote client limit may be reached." : "RESULT: pushes arrive.")

// Trim is shown only for internal sources; a non-zero trim on a preamp channel would be hidden in the app.
print("\n== 3. Preamp feeding each input (/-ha/NN/index; 32-79 = AES50-A, -1 = internal) and its trim (0.5 = 0 dB)")
for input in 1...32 {
    let headamp = await ask(Catalog.headampIndex(forInput: input))
    let trim = await ask(Catalog.trim(StripID(.input, input)).address)
    print(
        String(format: "ch %02d -> ", input) + (headamp.map(describe) ?? "NO REPLY") + "   trim "
            + (trim.map(describe) ?? "NO REPLY"))
}

print("\n== 4. Names and DCA masks: compare with the DCA assignments on the desk")
for input in 1...32 {
    let strip = StripID(.input, input)
    let name = await ask(strip.name)?.string(at: 0) ?? "?"
    var mask = "?"
    if case .int(let value)? = await ask(strip.dcaMask!)?.arguments.first {
        mask = zeroPadded(String(value, radix: 2), to: 8)
    }
    print(String(format: "ch %02d ", input) + "\"\(name)\" dca bits (DCA8..DCA1) \(mask)")
}

print("\n== 5. Meters: push a few DCA faders up on the desk now")
recorder.clear()
transport.send(OSCMessage("/meters", [.string("/meters/1")]))
transport.send(OSCMessage("/meters", [.string("/meters/5"), .int(0), .int(0)]))
try? await Task.sleep(for: .seconds(2))
for bank in ["/meters/1", "/meters/5"] {
    guard case .blob(let blob)? = recorder.last(address: bank)?.arguments.first else {
        print("\(bank) NO REPLY")
        continue
    }
    let values = MeterBlob.floats(from: blob)
    print("\(bank) count \(values.count)")
    print(
        values.enumerated().map { "\($0.offset):" + String(format: "%.3f", $0.element) }.joined(
            separator: " "))
}
print("For /meters/5, note which DCA faders were up: DCA meters are expected at 16-23.")

// The app borrows the desk's RTA while an EQ tab is open. The doc doesn't say /meters/15 follows
// /-prefs/rta/source, or whether "after EQ" includes the low cut and dynamics; the engineer sets it here.
print("\n== 6. RTA: on the desk, set the RTA source to a channel with signal (try before and after EQ)")
for address in [RTA.source, RTA.position] {
    print(await ask(address).map(describe) ?? "\(address) NO REPLY")
}
print("(source: 2-33 = Ch 1-32, 50-65 = Bus 1-16, 72 = Main; position: 0 = before EQ, 1 = after EQ)")
recorder.clear()
transport.send(RTA.subscription)
try? await Task.sleep(for: .seconds(3))
if case .blob(let blob)? = recorder.last(address: RTA.bank)?.arguments.first {
    let bands = MeterBlob.rtaDecibels(from: blob)
    let loudest = bands.indices.max { bands[$0] < bands[$1] } ?? 0
    let average = bands.isEmpty ? 0 : bands.reduce(0, +) / Float(bands.count)
    print(
        "\(RTA.bank) \(bands.count) bands, loudest \(String(format: "%.0f", RTA.bandFrequency(loudest))) Hz at "
            + String(format: "%.1f dB, average %.1f dB", bands.isEmpty ? 0 : bands[loudest], average))
    print("RESULT: compare with the desk's RTA screen; change the source or EQ and re-run to see it follow.")
} else {
    print("\(RTA.bank) NO REPLY: the spectrum is not streamed to remotes.")
}
transport.cancel()

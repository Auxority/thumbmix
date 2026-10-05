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

print("\n== 3. Preamp feeding each input (/-ha/NN/index; 32-79 = AES50-A, -1 = internal)")
for input in 1...32 {
    let reply = await ask(Catalog.headampIndex(forInput: input))
    print(String(format: "ch %02d -> ", input) + (reply.map(describe) ?? "NO REPLY"))
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
transport.cancel()

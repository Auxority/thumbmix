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

/// Everything the desk pushes for `seconds` while the engineer acts, with /xremote renewed before it lapses.
@MainActor
func listen(seconds: Int) async -> [OSCMessage] {
    recorder.clear()
    for elapsed in 0..<seconds {
        if elapsed % 9 == 0 { transport.send(OSCMessage("/xremote")) }
        try? await Task.sleep(for: .seconds(1))
    }
    return recorder.messages.filter { !$0.address.hasPrefix("/meters") }
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

// Since #26 the app shows trim on every input; the doc lists /ch/NN/preamp/trim as "(digital sources only)" (p.25).
// These answers decide whether that stays, or trim shows only for card (e.g. Dante) inputs or in playback mode.
print("\n== 3. Inputs: where each channel's signal comes from, its preamp gain and its trim")
print(await ask("/config/routing/routswitch").map(describe) ?? "routswitch NO REPLY")
print("(routswitch 0 = Rec: inputs use the IN blocks; 1 = Playback: they use the PLAY blocks)")
for bank in ["IN", "PLAY"] {
    for block in ["1-8", "9-16", "17-24", "25-32"] {
        let address = "/config/routing/\(bank)/\(block)"
        print(await ask(address).map(describe) ?? "\(address) NO REPLY")
    }
}
print("(blocks: 0-3 = local preamps AN, 4-9 = AES50-A, 10-15 = AES50-B, 16-19 = CARD (e.g. Dante), 20-23 = USB)")
for input in 1...32 {
    let strip = StripID(.input, input)
    let feed = await ask(strip.prefix + "/config/source")
    let headamp = await ask(Catalog.headampIndex(forInput: input))
    var gain: OSCMessage?
    if case .int(let index)? = headamp?.arguments.first, (0...127).contains(index) {
        gain = await ask(Catalog.headampGain(Int(index)).address)
    }
    let trim = await ask(Catalog.trim(strip).address)
    let values = [feed, headamp, gain, trim].map { $0.map { describe($0).split(separator: " ").dropFirst().joined() } }
    print(
        String(format: "ch %02d", input) + " source " + (values[0] ?? "?") + "  headamp " + (values[1] ?? "?")
            + "  gain " + (values[2] ?? "-") + "  trim " + (values[3] ?? "?"))
}
print("(source 1-32 = In01-32; headamp -1 = no preamp; gain and trim 0.5 = 0 dB)")
print("RESULT: on the desk, open the preamp page of a channel fed by a preamp (AN or AES50) and of one fed by the")
print("card, in Rec and in Playback: note whether the desk offers Gain, Trim or both. Turn trim on a preamp channel")
print("and listen: does it change the level?")

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

// The app models stereo links from the user's desk observations and a forum/video summary (notes spec); these
// answers go in comments at StripLink.swift (LinkSection.of) and FakeM32.linkEffects.
print("\n== 7. Stereo links")
for address in Catalog.linkAddresses {
    let reply = await ask(address)
    if address.contains("linkcfg") || reply?.arguments.first == .int(1) { print(reply.map(describe) ?? "\(address) NO REPLY") }
}
print("(linkcfg 1 = ticked in Setup > config > Link Preferences; pairs listed only when linked)")

print("\n7a. In MIXING STATION (not on the desk), move the fader of a linked pair during the next 15 seconds...")
let faders = await listen(seconds: 15).filter { $0.address.hasSuffix("/mix/fader") }
print("faders pushed: " + Set(faders.map(\.address)).sorted().joined(separator: ", "))
print("RESULT: both sides listed = the desk (or Mixing Station) moved the partner; one side = nobody did.")

print("\n7b. On the DESK, link two channels you don't use during the next 20 seconds...")
let linking = await listen(seconds: 20)
for push in linking where push.address.contains("link") || push.address.hasSuffix("/mix/pan") { print("  " + describe(push)) }
print("RESULT: the pans show what linking set; any other pushes above are settings the desk copied.")

print("\n7c. On the DESK, untick EQ Link, then change band 1 gain of one side of a linked pair (25 seconds)...")
let eqEdits = await listen(seconds: 25).filter { $0.address.hasSuffix("/eq/1/g") }
print("band 1 gains pushed: " + Set(eqEdits.map(\.address)).sorted().joined(separator: ", "))
print("RESULT: one side = an unticked preference separates the sides (the app's L | R switch is right).")

print("\n7d. On the DESK, untick Mute/Fader Link, then move a send (bus 1) of a linked pair (20 seconds)...")
let sends = await listen(seconds: 20).filter { $0.address.hasSuffix("/mix/01/level") }
print("bus 1 sends pushed: " + Set(sends.map(\.address)).sorted().joined(separator: ", "))
print("RESULT: one side = sends follow Mute/Fader Link (the app's guess); both = they're always linked.")
print("Tick EQ Link and Mute/Fader Link again before the show.")
transport.cancel()

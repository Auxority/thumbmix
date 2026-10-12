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

@MainActor
func ask(_ address: String) async -> OSCMessage? {
    for _ in 1...3 {
        recorder.clear()
        transport.send(OSCMessage(address))
        if let reply = await recorder.wait(for: address, timeout: .milliseconds(500)) { return reply }
    }
    return nil
}

/// The desk's text for a node, e.g. "ch/01/mix" → "/ch/01/mix ON -12.5 OFF +0 OFF -oo". The reply's address
/// is "node", without the slash (doc p.80).
@MainActor
func askNode(_ path: String) async -> String? {
    for _ in 1...3 {
        recorder.clear()
        transport.send(OSCMessage("/node", [.string(path)]))
        if case .string(let text)? = await recorder.wait(for: "node", timeout: .milliseconds(500))?.arguments.first {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
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

/// One strip's source, headamp, gain and trim on one line; gain only when a preamp feeds it.
@MainActor
func preampLine(_ strip: StripID) async -> String {
    guard let headampAddress = Catalog.headampIndex(strip) else { return strip.defaultName + " has no preamp slot" }
    let feed = await ask(strip.prefix + "/config/source")
    let headamp = await ask(headampAddress)
    var gain: OSCMessage?
    if case .int(let index)? = headamp?.arguments.first, (0...127).contains(index) {
        gain = await ask(Catalog.headampGain(Int(index)).address)
    }
    let trim = await ask(Catalog.trim(strip).address)
    let values = [feed, headamp, gain, trim].map { $0.map { describe($0).split(separator: " ").dropFirst().joined() } }
    return strip.defaultName + " source " + (values[0] ?? "?") + "  headamp " + (values[1] ?? "?")
        + "  gain " + (values[2] ?? "-") + "  trim " + (values[3] ?? "?")
}

print("== 1. Identity")
for address in ["/info", "/xinfo", "/status"] {
    print(await ask(address).map(describe) ?? "\(address) NO REPLY")
}

print("\n== 2. Push test: keep the Mixing Station clients connected.")
print("Move any fader on the desk or in Mixing Station during the next 20 seconds...")
let pushes = await listen(seconds: 20)
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
for strip in StripID.all(.input) { print(await preampLine(strip)) }
print("(source 1-32 = In01-32; headamp -1 = no preamp; gain and trim 0.5 = 0 dB)")
print("RESULT: on the desk, open the preamp page of a channel fed by a preamp (AN or AES50) and of one fed by the")
print("card, in Rec and in Playback: note whether the desk offers Gain, Trim or both. Turn trim on a preamp channel")
print("and listen: does it change the level?")

// The app shows Gain and 48V on an aux in whose /-ha slot names a preamp (doc p.43); the doc doesn't say whether
// the desk fills slots 32-39 when it routes aux ins from inputs (/config/routing/IN/AUX, doc p.21).
print("\n== 3b. Aux ins: routing, preamp and trim")
print(await ask("/config/routing/IN/AUX").map(describe) ?? "IN/AUX NO REPLY")
print("(0 = the AUX jacks, 1-3 = AN1-2/1-4/1-6, 4-6 = AES50-A, 7-9 = AES50-B, 10-12 = CARD, 13-15 = UIN)")
for strip in StripID.all(.auxIn) { print(await preampLine(strip)) }
print("RESULT: with the jacks (0), every aux headamp should be -1. On the DESK, route aux 1-2 from AN1-2 (or A1-2)")
print("and run again: aux 1's headamp should match the channel on that input. Then route the aux ins back.")

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

// The app files polarity under Gain/Delay (LinkSection.of) and its Ø alert names the partner on that assumption.
print("\n7e. On the DESK, with Gain/Delay Link ticked, flip the polarity (Ø) of one side of a linked pair (20 seconds)...")
let flips = await listen(seconds: 20).filter { $0.address.hasSuffix("/preamp/invert") }
print("polarity pushed: " + Set(flips.map(\.address)).sorted().joined(separator: ", "))
print("RESULT: both sides = the link carries polarity (the app's model); one side = it doesn't. Flip it back.")
// The doc lists a matrix polarity (p.32) that Mixing Station doesn't show: an answer means it exists.
print("\n7f. " + (await ask("/mtx/01/config/preamp/invert").map(describe) ?? "matrix polarity: NO REPLY (no such setting)"))

// The app shows each fader step as the doc's table has it (p.145, FaderLaw.shownDecibels), including a detent
// that reads 0 from -0.09 to +0.07 dB and two steps rounded the other way. The desk's own text checks that.
print("\n== 8. Fader text: with the desk's encoder, set a few input faders to about 0 dB, -8.6 and -23.2 first")
var faderMismatches = 0
for input in 1...32 {
    let strip = StripID(.input, input)
    guard case .float(let wire)? = await ask(strip.fader)?.arguments.first,
        let node = await askNode(String(strip.prefix.dropFirst()) + "/mix")
    else {
        print(String(format: "ch %02d NO REPLY", input))
        continue
    }
    // The mix node lists on, fader, stereo, pan, mono, mono level; the fader is the third word.
    let deskText = node.split(separator: " ").dropFirst(2).first.map(String.init) ?? "?"
    let desk = deskText == "-oo" ? -Double.infinity : Double(deskText)
    let app = FaderLaw.shownDecibels(fromWire: Double(wire))
    if desk != app { faderMismatches += 1 }
    let step = Int((Double(wire) * 1023).rounded())
    print(String(format: "ch %02d step %4d ", input, step) + "desk \(deskText) app \(app)" + (desk == app ? "" : "  <- DIFFERS"))
}
print("RESULT: \(faderMismatches) of 32 differ. Each DIFFERS line goes in FaderLaw.deskExceptions (by step).")

// The Sends tab shows a linked bus pair as one send with a pan (Catalog.sendPan, ConsoleMirror.sendTargets),
// assuming the desk copies the odd send to the even one.
print("\n== 9. Send pan: on the DESK, link buses 1-2, then move channel 1's send to them (20 seconds)...")
let pairSends = await listen(seconds: 20).filter { $0.address.hasPrefix("/ch/01/mix/0") && $0.address.hasSuffix("/level") }
print("sends pushed: " + Set(pairSends.map(\.address)).sorted().joined(separator: ", "))
print("RESULT: /mix/01 and /mix/02 = the desk copies the odd send (the app's guess); /mix/01 only = it doesn't.")

// The app keeps a linked channel pair's send pans per side (LinkSection.of), like its LR pans.
print("\n9a. On the DESK, keep buses 1-2 linked, then turn the bus 1-2 send pan of one side of a linked channel pair (20 s)...")
let pairPans = await listen(seconds: 20).filter { $0.address.hasSuffix("/mix/01/pan") }
print("send pans pushed: " + Set(pairPans.map(\.address)).sorted().joined(separator: ", "))
print("RESULT: one channel = each side keeps its own (the app's guess); both = the desk copies it.")

/// A bus's average level in dB over `seconds`, from the bus meters (/meters/2, doc p.17-19).
@MainActor
func busLevel(_ bus: Int, seconds: Int) async -> Float? {
    recorder.clear()
    transport.send(OSCMessage("/meters", [.string("/meters/2")]))
    try? await Task.sleep(for: .seconds(seconds))
    let levels = recorder.messages.filter { $0.address == "/meters/2" }.compactMap { message -> Float? in
        guard case .blob(let blob)? = message.arguments.first else { return nil }
        return MeterBanks.readings(address: "/meters/2", values: MeterBlob.floats(from: blob))[StripID(.bus, bus)]?.level
    }
    guard !levels.isEmpty else { return nil }
    return 20 * log10(max(levels.reduce(0, +) / Float(levels.count), 1e-6))
}

/// The engineer sets `first` on the desk, then `second`; the probe measures `bus` after each and prints both.
@MainActor
func compare(bus: Int, _ first: String, _ second: String) async -> Float? {
    var levels: [Float] = []
    for step in [first, second] {
        print("  On the DESK: \(step) (10 seconds), then hands off while it measures...")
        try? await Task.sleep(for: .seconds(10))
        guard let level = await busLevel(bus, seconds: 4) else {
            print("  bus \(bus) meters: NO REPLY")
            return nil
        }
        print(String(format: "  bus %d: %.1f dB", bus, level))
        levels.append(level)
    }
    return levels[1] - levels[0]
}

func change(_ difference: Float?) -> String {
    difference.map { String(format: "%+.1f dB", $0) } ?? "unknown"
}

// The tap point's chain (TapChain) and its explanations rest on these; one tutorial and the user's memory so far.
print("\n== 10. Tap points. Set up on the DESK first: channel 1 with a steady signal (pink noise or a track),")
print("buses 15-16 unused, unlinked, faders at 0 dB and unmuted, channel 1's sends to bus 15 and 16 at 0 dB.")
print("\n10a. Comp before the EQ: set channel 1's comp before the EQ, threshold -40, ratio 10; its bus 15-16 tap <-EQ.")
let compChange = await compare(bus: 15, "channel 1's comp ON", "channel 1's comp OFF")
print("RESULT: \(change(compChange)). Louder with it off (> +2 dB) = a Pre-EQ send includes a comp set before the EQ (the app's model).")

print("\n10b. One tap for both buses: set the bus 15-16 tap to PRE; listen on bus 16, the even one.")
let evenChange = await compare(bus: 16, "channel 1's fader at 0 dB", "channel 1's fader all the way down")
print("RESULT: \(change(evenChange)). About 0 = bus 16 is pre-fader too: the odd send's tap sets the pair (the app's model).")

print("\n10c. Mute and pre-fader sends: keep the tap at PRE, channel 1's fader at 0 dB.")
let muteChange = await compare(bus: 15, "channel 1 unmuted", "channel 1 MUTED")
print("RESULT: \(change(muteChange)). A big drop = muting a channel silences its pre-fader sends too.")

print("\n10d. Subgroup: set the bus 15-16 tap to GRP.")
let groupChange = await compare(bus: 15, "channel 1's bus 15 send at 0 dB", "channel 1's bus 15 send at -20 dB")
print("RESULT: \(change(groupChange)). About 0 = a subgroup send's level is fixed (the app's model).")

print("\n10e. Follow LR pan: link buses 15-16, tap PRE, channel 1 panned centre, its send's Follow LR pan ON.")
let followChange = await compare(bus: 15, "channel 1's bus 15-16 send pan hard left", "send pan hard right")
print("RESULT: \(change(followChange)). About 0 = the send's own pan is ignored while it follows (the app dims it).")
print("Put buses 15-16 and channel 1 back as the show needs them.")

await probeEQDefaults()
await probeReadTiming()

transport.cancel()

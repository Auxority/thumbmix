import ThumbmixCore

/// Section 17. The doc only names /config/mono/mode (LR+M or LCR) and /config/mono/link ("M/C depends on Main
/// L/R", p.21); the M32 manual (Setup, global) says in LCR the pan reaches the centre. Main M's Fed by shows the
/// same rows either way (DECISIONS) until this answers.
@MainActor
func probeMonoMode() async {
    print("\n== 17. Mono mode. Setup: channel 1 with a steady signal, fader 0 dB, panned centre, to Main LR and to")
    print("Main M with its M/C level at 0 dB; every other channel down; Main LR and Main M faders at 0 dB.")
    for address in ["/config/mono/mode", "/config/mono/link"] {
        print(await ask(address).map(describe) ?? "\(address) NO REPLY")
    }
    print("(mode 0 = LR+M, 1 = LCR; link 1 = M/C depends on Main L/R)")

    print("\n17a. On the DESK, in Setup > global, set the panning mode to LCR, then press Enter.")
    _ = readLine()
    let pan = await compareTaps(mainTaps, "channel 1 panned centre", "channel 1 panned hard left")
    print("RESULT: Main M \(change(pan?[0])), Main L \(change(pan?[1])), Main R \(change(pan?[2])). Main M dropping")
    print("= in LCR the pan sends the centre's share to Main M.")

    print("\n17b. Still LCR, channel 1 panned centre again.")
    let level = await compareTaps(mainTaps, "channel 1's M/C level at 0 dB", "its M/C level at -20 dB")
    print("RESULT: Main M \(change(level?[0])), Main L \(change(level?[1])), Main R \(change(level?[2])). Main M about")
    print("-20 and L/R about 0 = the M/C level still sets the centre alone; L/R changing too = it works as a balance.")

    print("\n17c. On the DESK, set the panning mode back to LR+M and tick \"M/C depends on Main L/R\" (the doc's name),")
    print("then press Enter.")
    _ = readLine()
    let link = await compareTaps([mainTaps[0]], "channel 1's LR switch ON", "its LR switch OFF")
    print("RESULT: Main M \(change(link?.first)). A big drop = with the link, a strip reaches Main M only through its LR")
    print("switch (Main M's Fed by says so); about 0 = it doesn't gate the strips.")
    print("Put the panning mode, the link and channel 1 back as the show needs them.")
}

/// Main M, L and R in the bus meters (doc p.17).
private let mainTaps = [
    MeterTap("Main M", [.string("/meters/2")], 24),
    MeterTap("Main L", [.string("/meters/2")], 22),
    MeterTap("Main R", [.string("/meters/2")], 23),
]

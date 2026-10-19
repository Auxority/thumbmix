import ThumbmixCore

/// Section 16. Under the desk's Exclusive solo (p.21; M32 manual, Monitor: "pressing another SOLO button disengages
/// the previous solo") the app asks before a stroke adds a solo (`SoloStroke`). The doc doesn't say the desk applies
/// it to solos sent over OSC; the fake desk assumes it does.
@MainActor
func probeExclusiveSolo() async {
    print("\n== 16. Exclusive solo")
    print(await ask(Catalog.exclusiveSolo).map(describe) ?? "\(Catalog.exclusiveSolo) NO REPLY")
    print("16a. On the DESK, in the MONITOR screen, turn Exclusive solo on and clear every solo, then press Enter.")
    _ = readLine()
    print(await ask(Catalog.exclusiveSolo).map(describe) ?? "\(Catalog.exclusiveSolo) NO REPLY")

    print("\n16b. In MIXING STATION, solo channel 1, then channel 2, during the next 15 seconds...")
    print("(If Mixing Station has its own exclusive solo option, turn it off first: it would unsolo channel 1 itself.)")
    let watched = [StripID(.input, 1).solo, StripID(.input, 2).solo]
    for push in await listen(seconds: 15) where watched.contains(push.address) { print("  " + describe(push)) }
    for address in watched { print(await ask(address).map(describe) ?? "\(address) NO REPLY") }
    print("RESULT: channel 1 (solosw/01) 0 and channel 2 (solosw/02) 1 = the desk applies Exclusive to remote solos")
    print("(the app's model, SoloStroke asks first); both 1 = it doesn't, and the app's question goes.")
    print("Clear the solos, and turn Exclusive solo off again if the show doesn't use it.")
}

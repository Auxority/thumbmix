import ThumbmixCore

/// Section 19. The Mix tab shows a strip's insert read-only (`Catalog.insert`) until four things the doc leaves open
/// are known: what Pre/Post means on a channel, whether an unpatched aux slot silences the strip (the app asks
/// first, DECISIONS), whether a linked pair's insert follows the link, and what picking a held slot does.
@MainActor
func probeInserts() async {
    print("\n== 19. Inserts: the slots strips hold now")
    await printInsertSlots()

    print("\n19a. On the DESK, select channel 1 and open HOME > home, its signal path. On HOME > config, switch the")
    print("insert between Pre and Post: where does the insert sit in the path each time? Then press Enter.")
    _ = readLine()
    print("RESULT: note it. Before/after the EQ = the app's \"Before EQ / After EQ\" is right for channels; before/after")
    print("the fader (as the manual's home page puts it) = fix Catalog.insert's option names.")

    print("\n19b. Setup: channel 1 with a steady signal, fader 0 dB; nothing plugged into AUX OUT 6 or AUX IN 6.")
    let silenced = await compareTaps([channelOut], "channel 1's insert OFF", "its insert ON, slot AUX6, Post")
    print("RESULT: \(change(silenced?.first)). A big drop = an unpatched aux slot silences the strip (the app's alert")
    print("stays); about 0 = it doesn't (the alert goes, DECISIONS).")

    print("\n19c. Keep the insert on AUX6.")
    let returned = await compareTaps([channelOut], "nothing in AUX IN 6", "a phone playing into AUX IN 6")
    print("RESULT: \(change(returned?.first)). Channel 1 rising = AUX IN 6 is the insert's return. Turn the insert off.")

    await probeLinkedInsert()
    await probeHeldSlot()
}

private let channelOut = MeterTap("channel 1 post-fade", [.string("/meters/6"), .int(0)], 3)

/// Every strip whose insert has a slot, e.g. "Ch 05 FX3L Post on".
@MainActor
private func printInsertSlots() async {
    for strip in StripKind.allCases.flatMap(StripID.all) {
        guard let insert = Catalog.insert(strip) else { continue }
        guard case .int(let slot)? = await ask(insert.slot.address)?.arguments.first,
            Catalog.insertSlots.indices.contains(Int(slot))
        else {
            print("  \(insert.slot.address) NO REPLY")
            continue
        }
        guard slot != 0 else { continue }
        let position = await ask(insert.position.address)?.arguments.first == .int(1) ? "Post" : "Pre"
        let on = await ask(insert.on.address)?.arguments.first == .int(1) ? "on" : "off"
        print("  " + strip.defaultName + " " + Catalog.insertSlots[Int(slot)] + " \(position) \(on)")
    }
}

/// The app files the insert under the Dynamics Link Preference (a guess, TODO "Inserts").
@MainActor
private func probeLinkedInsert() async {
    print("\n19d. On the DESK, with Dynamics Link ticked, switch the insert on for one side of a linked pair of unused")
    print("channels (20 seconds)...")
    let ticked = await listen(seconds: 20).filter { $0.address.hasSuffix("/insert/on") }
    print("inserts pushed: " + Set(ticked.map(\.address)).sorted().joined(separator: ", "))
    print("Now untick Dynamics Link and switch that side's insert off again (20 seconds)...")
    let unticked = await listen(seconds: 20).filter { $0.address.hasSuffix("/insert/on") }
    print("inserts pushed: " + Set(unticked.map(\.address)).sorted().joined(separator: ", "))
    print("RESULT: both sides, then one = the insert follows Dynamics Link (the app's guess); both sides twice = it")
    print("always follows, or another preference governs it; one side twice = it never follows. Tick Dynamics Link again.")
}

/// The planned Slot menu asks before taking a slot another strip holds (TODO "Make the insert slot editable").
@MainActor
private func probeHeldSlot() async {
    print("\n19e. On the DESK, pick slot AUX5 as the insert of an unused channel A, then pick AUX5 on another unused")
    print("channel B (25 seconds)...")
    let picks = await listen(seconds: 25).filter { $0.address.hasSuffix("/insert/sel") }
    for push in picks { print("  " + describe(push)) }
    await printInsertSlots()
    print("RESULT: A's slot pushed to 0 = picking a held slot takes it from A (the planned menu asks first); A and B both")
    print("on AUX5 = strips can share a slot; B not on AUX5 = the desk refuses. Set A's and B's slots back to OFF.")
}

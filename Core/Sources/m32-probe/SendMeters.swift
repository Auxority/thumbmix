import Foundation
import ThumbmixCore

/// Section 13. A meter per Fed by row would show what each source puts into the bus (its tap point plus the send
/// level). The doc lists "16 bus send meters" (/meters/7, p.18) without saying whose sends; if they are the desk's
/// selected channel's (/-stat/selidx, p.61), a real meter is possible. Same setup as section 10.
@MainActor
func probeSendMeters() async {
    print("\n== 13. Send meters. Setup as in 10: channel 1 with a steady signal, its bus 15 send at 0 dB, tap PRE.")
    print("13a. On the DESK, press channel 1's SELECT, then press Enter.")
    _ = readLine()
    print(await ask("/-stat/selidx").map(describe) ?? "/-stat/selidx NO REPLY")
    print("(selidx 0-31 = Ch 1-32)")
    await printLevels("/meters/7", [.string("/meters/7")])
    await printLevels("/meters/6 ch 1", [.string("/meters/6"), .int(0)])
    print("(/meters/6: post gain/trim, gate, dyn gain reduction, post-fade, per the doc)")

    print("\n13b. Does slot 15 follow channel 1's bus 15 send?")
    let sendChange = await compareTaps([sendSlot], "channel 1's bus 15 send at 0 dB", "channel 1's bus 15 send at -20 dB")?.first
    print("RESULT: \(change(sendChange)). About -20 = /meters/7 slot 15 is channel 1's send into bus 15.")

    print("\n13c. Does it follow the selection?")
    let selectChange = await compareTaps([sendSlot], "channel 1 SELECTED", "a silent channel SELECTED")?.first
    print("RESULT: \(change(selectChange)). A big drop = the meters are the selected channel's sends (one strip at a time).")

    print("\n13d. Over 0 dBFS: select channel 1, tap POST, channel 1's fader at +10 dB and its bus 15 send at +10 dB.")
    print("  On the DESK: set that up (10 seconds), then hands off while it measures...")
    try? await Task.sleep(for: .seconds(10))
    let peak = await tapLevels([sendSlot], seconds: 4, peak: true)?.first
    print("  slot 15 peak: " + (peak.map { String(format: "%.3f (%.1f dB)", $0, decibels($0)) } ?? "NO REPLY"))
    print("RESULT: above 1.000 = the meter reports past 0 dBFS (a Fed by row could show clipping); 1.000 = it stops there.")
    print("Put channel 1's fader, its sends and buses 15-16 back as the show needs them.")
}

/// /meters/7 slot 15: bus 15's send meter.
private let sendSlot = MeterTap("slot 15", [.string("/meters/7")], 14)

@MainActor
private func printLevels(_ label: String, _ request: [OSCArgument]) async {
    guard let levels = await slotAverages([request], seconds: 3).values.first else {
        print("\(label) NO REPLY")
        return
    }
    print(
        "\(label) count \(levels.count): "
            + levels.enumerated().map { "\($0.offset + 1):" + String(format: "%.1f", decibels($0.element)) }.joined(separator: " "))
}

import Foundation
import ThumbmixCore

/// Section 14. The app shows the six mute groups (`/config/mute/1-6`, p.21) and a red-bordered M on every strip a
/// group mutes, from each strip's `grp/mute` mask (p.27-38). The doc leaves three things open, answered here.
@MainActor
func probeMuteGroups() async {
    print("\n== 14. Mute groups: compare with the mute group assignments on the desk")
    for group in 1...Catalog.muteGroupCount {
        print(await ask(Catalog.muteGroup(group)).map(describe) ?? "\(Catalog.muteGroup(group)) NO REPLY")
    }
    for input in 1...32 {
        let strip = StripID(.input, input)
        var mask = "?"
        if case .int(let value)? = await ask(strip.muteGroupMask!)?.arguments.first {
            mask = zeroPadded(String(value, radix: 2), to: 6)
        }
        print(String(format: "ch %02d ", input) + "mute group bits (MG6..MG1) \(mask)")
    }
    print("RESULT: the app reads bit 0 as mute group 1. A channel in MG1 only should end in 1.")

    print("\n14b. On the DESK, put channel 1 in mute group 1, then switch mute group 1 on and off during the next 20 seconds...")
    let pushes = await listen(seconds: 20)
    let watched: Set<String> = [Catalog.muteGroup(1), StripID(.input, 1).muteGroupMask!, StripID(.input, 1).on]
    for push in pushes where watched.contains(push.address) { print("  " + describe(push)) }
    print("RESULT: /config/mute/1 listed = the desk pushes a group switch to remotes (else the app only sees it when the")
    print("Main page opens). /ch/01/mix/on listed = a group mute changes the strip's own mute (the app assumes it doesn't).")
    print("Take channel 1 out of mute group 1 again if the show doesn't want it there.")
}

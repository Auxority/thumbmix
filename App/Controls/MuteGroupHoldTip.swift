import SwiftUI
import TipKit

/// A hold is invisible, and the app should never need a manual (the user, 2026-10-19): the Main page says how to
/// choose a group's strips until the engineer has opened a group by holding it once.
struct MuteGroupHoldTip: Tip {
    static let openedByHolding = Event(id: "muteGroupOpenedByHolding")

    var title: Text { Text("Choose who's in a group") }

    var message: Text? { Text("Hold a mute group to choose its strips.") }

    var rules: [Rule] {
        #Rule(Self.openedByHolding) { $0.donations.count == 0 }
    }
}

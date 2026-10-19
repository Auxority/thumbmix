import SwiftUI
import TipKit

/// A hold-and-drag is invisible, and the app should never need a manual (the user, 2026-10-19): the overview's first
/// name says how, every time, until the engineer has soloed by holding a name once.
struct SoloStrokeTip: Tip {
    static let soloedByHolding = Event(id: "soloedByHolding")

    var title: Text { Text("Solo several at once") }

    var message: Text? { Text("Hold a name to solo it. Keep holding and drag to solo more.") }

    var rules: [Rule] {
        #Rule(Self.soloedByHolding) { $0.donations.count == 0 }
    }
}

import SwiftUI
import ThumbmixCore

/// A list's rows that hold still while a finger is down: a link changed on the desk mid-drag would rebuild the row
/// under the finger. The change is drawn once the finger lifts.
struct SteadyRows<Content: View>: View {
    let wanted: [OverviewItem]
    let mirror: ConsoleMirror
    @ViewBuilder let content: ([OverviewItem]) -> Content
    /// The rows as they were when a finger last went down.
    @State private var held: [OverviewItem] = []

    var body: some View {
        // Computed as the list draws while no finger is down: a cached list missed the last of a status and link
        // change arriving together and left a linked pair split (2026-10-12, once connect got ~10x faster).
        content(mirror.isFingerDown ? held : wanted)
            .onChange(of: wanted, initial: true) { if !mirror.isFingerDown { held = wanted } }
            .task(id: wanted) { await regroupOnceTheFingerLifts() }
    }

    /// The next change or leaving the screen cancels the wait.
    private func regroupOnceTheFingerLifts() async {
        do { try await mirror.fingerLifted() } catch { return }
        held = wanted
    }
}

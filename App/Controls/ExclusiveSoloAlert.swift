import SwiftUI
import ThumbmixCore

extension View {
    /// The Exclusive solo question, and the ways a stroke ends without a lift. Kept outside the list's `.disabled`: an
    /// alert whose buttons change enabled state while open loses their actions (CLAUDE.md).
    func soloStrokeLifecycle(_ stroke: SoloStrokeDriver, mirror: ConsoleMirror, onKeep: @escaping () -> Void) -> some View {
        modifier(SoloStrokeLifecycle(stroke: stroke, mirror: mirror, onKeep: onKeep))
    }
}

private struct SoloStrokeLifecycle: ViewModifier {
    @Bindable var stroke: SoloStrokeDriver
    let mirror: ConsoleMirror
    let onKeep: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .exclusiveSoloAlert(isPresented: $stroke.isAskingExclusive, mirror: mirror, onKeep: onKeep)
            .onChange(of: mirror.soloStroke == nil) { _, ended in
                if ended { stroke.strokeEnded() }
            }
            // A call or Notification Center cancels the touch without an end (CLAUDE.md, held gestures).
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { mirror.abandonSoloStroke() }
            }
            .onDisappear { mirror.abandonSoloStroke() }
    }
}

extension View {
    /// Asked once a stroke's finger lifts on rows held back (option C, 2026-10-19): the desk's Exclusive solo would keep
    /// only the last of them. Keep isn't asked again for this desk until the app quits (`onKeep`).
    fileprivate func exclusiveSoloAlert(
        isPresented: Binding<Bool>, mirror: ConsoleMirror, onKeep: @escaping () -> Void
    ) -> some View {
        alert("Exclusive solo is on", isPresented: isPresented) {
            Button("Turn off") { mirror.answerExclusiveSolo(turnOff: true) }
            Button("Keep", role: .cancel) {
                mirror.answerExclusiveSolo(turnOff: false)
                onKeep()
            }
        } message: {
            Text("The desk keeps one solo at a time. Turn it off?")
        }
    }
}

import SwiftUI
import ThumbmixCore

extension View {
    /// Asked once a stroke's finger lifts on rows held back (option C, 2026-10-19): the desk's Exclusive solo would keep
    /// only the last of them. Keep isn't asked again for this desk until the app quits (`onKeep`).
    func exclusiveSoloAlert(isPresented: Binding<Bool>, mirror: ConsoleMirror, onKeep: @escaping () -> Void) -> some View {
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

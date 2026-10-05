import SwiftUI
import ThumbmixCore

struct OverviewView: View {
    let mirror: ConsoleMirror
    let onDisconnect: () -> Void

    var body: some View {
        NavigationStack {
            List(StripGroup.inputs.strips) { strip in
                Text(mirror.name(strip))
            }
            .safeAreaInset(edge: .top, spacing: 0) { StatusBanner(status: mirror.status) }
            .toolbar { Button("Disconnect", action: onDisconnect) }
        }
    }
}

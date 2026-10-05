import SwiftUI
import ThumbmixCore

@main
struct ThumbmixApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}

struct RootView: View {
    let model: AppModel

    var body: some View {
        Group {
            if let mirror = model.mirror, model.failure == nil {
                OverviewView(mirror: mirror, onDisconnect: model.disconnect)
            } else {
                ConnectView(model: model)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .task { model.connectToLastConsole() }
    }
}

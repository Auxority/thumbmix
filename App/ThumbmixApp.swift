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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let mirror = model.mirror, model.failure == nil {
                OverviewView(mirror: mirror, onDisconnect: model.disconnect)
                    .environment(\.isDemoConsole, model.isOffline)
            } else {
                ConnectView(model: model)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .task { model.connectToLastConsole() }
        .onChange(of: scenePhase) { old, new in
            if old == .background, new != .background { model.wake() }
        }
    }
}

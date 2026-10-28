import OSLog
import SwiftUI
import ThumbmixCore
import TipKit

@main
struct ThumbmixApp: App {
    @State private var model = AppModel()

    init() {
        // UI tests launch with -disableAnimations YES: every step waits for the screen to settle first.
        if UserDefaults.standard.bool(forKey: "disableAnimations") { UIView.setAnimationsEnabled(false) }
        #if DEBUG
            // UI tests pick whether lists start folded. Written, not passed as the keys themselves: a launch argument
            // outranks what the app saves, so Show and Hide would do nothing.
            if UserDefaults.standard.object(forKey: "showsUnusedStrips") != nil {
                let shown = UserDefaults.standard.bool(forKey: "showsUnusedStrips")
                for key in UnusedFoldRow.storageKeys { UserDefaults.standard.set(shown, forKey: key) }
            }
            // UI tests hide tips, so a popover never covers what they tap; a tip's own test starts it fresh.
            switch UserDefaults.standard.string(forKey: "tips") {
            case "hidden": Tips.hideAllTipsForTesting()
            case "fresh": try? Tips.resetDatastore()
            default: break
            }
        #endif
        do {
            try Tips.configure()
        } catch {
            Logger(subsystem: "thumbmix", category: "app").error("tips not configured: \(error, privacy: .public)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .tint(.white)
                .modifier(ShakeToShareLog())
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let mirror = model.mirror, model.failure == nil {
                OverviewView(mirror: mirror, onDisconnect: model.disconnect, onKeepExclusive: model.keepExclusiveSolo)
                    .environment(\.isDemoConsole, model.isOffline)
                    // A new desk starts from the overview, with no screen, sheet or alert left open.
                    .id(ObjectIdentifier(mirror))
            } else {
                ConnectView(model: model)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .environment(\.presetLibrary, model.presets)
        #if DEBUG
            .task { model.connectOnLaunch() }
            .onOpenURL(perform: model.openTestURL)
        #endif
        .onChange(of: scenePhase) { old, new in
            if old == .background, new != .background { model.wake() }
        }
    }
}

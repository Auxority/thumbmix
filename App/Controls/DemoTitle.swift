import SwiftUI

extension EnvironmentValues {
    /// True while Offline mode runs: the console is the demo inside the app, not a mixer.
    @Entry var isDemoConsole = false
}

extension View {
    /// Shows the title with a DEMO pill in Offline mode. It sits in the title, not a banner, so no control moves.
    func demoTitle(_ title: String) -> some View {
        modifier(DemoTitle(title: title))
    }
}

private struct DemoTitle: ViewModifier {
    let title: String
    @Environment(\.isDemoConsole) private var isDemoConsole

    func body(content: Content) -> some View {
        content.toolbar {
            if isDemoConsole {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text(title).font(.headline)
                        Text("DEMO")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.demoPurple, in: Capsule())
                    }
                }
            }
        }
    }
}

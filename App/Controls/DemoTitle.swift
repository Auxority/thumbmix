import SwiftUI
import ThumbmixCore

extension EnvironmentValues {
    /// True while Offline mode runs: the console is the demo inside the app, not a mixer.
    @Entry var isDemoConsole = false
}

extension View {
    /// Shows the title with a DEMO pill in Offline mode. It sits in the title, not a banner, so no control moves.
    /// nil shows the pill alone, for a screen without a title (the overview). A soloed strip's title reads
    /// "Ch 1 · Solo", "· Solo" in yellow (H2, 2026-10-19), as its overview row's number line does.
    func demoTitle(_ title: String?, soloed: Bool = false) -> some View {
        modifier(DemoTitle(title: title, soloed: soloed))
    }
}

private struct DemoTitle: ViewModifier {
    let title: String?
    let soloed: Bool
    @Environment(\.isDemoConsole) private var isDemoConsole

    func body(content: Content) -> some View {
        content.toolbar {
            if isDemoConsole || soloed {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        if let title { titleText(title).font(.headline) }
                        if isDemoConsole { demoPill }
                    }
                }
            }
        }
    }

    private func titleText(_ title: String) -> Text {
        guard soloed else { return Text(verbatim: title) }
        var solo = AttributedString(" · \(ConsoleMirror.soloCaption(nil))")
        solo.foregroundColor = Theme.soloYellow
        return Text(AttributedString(title) + solo)
    }

    private var demoPill: some View {
        Text("DEMO")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.demoPurple, in: Capsule())
            // iOS 27's bar measured the pill too narrow ("DE…") even with room to spare.
            .fixedSize()
    }
}

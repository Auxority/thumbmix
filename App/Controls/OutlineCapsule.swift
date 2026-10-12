import SwiftUI

/// Black with a thin edge, for the buttons iOS would fill grey (toolbar glass, Connect), so the screen stays OLED black.
/// A prominent button fills white while enabled, like a selected chip.
struct OutlineCapsuleStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let filled = prominent && isEnabled
        configuration.label
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .foregroundStyle(filled ? Color.black : isEnabled ? Color.white : Theme.secondaryText)
            .background(filled ? Color.white : Theme.background, in: Capsule())
            .overlay { Capsule().strokeBorder(filled ? Color.clear : Theme.outline, lineWidth: 1) }
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(Capsule())
            // iOS 27's bar measured the capsule too narrow ("D…" for Disconnect), as it did the DEMO pill.
            .fixedSize()
    }
}

extension ButtonStyle where Self == OutlineCapsuleStyle {
    static var outlineCapsule: OutlineCapsuleStyle { OutlineCapsuleStyle() }
    static var prominentOutlineCapsule: OutlineCapsuleStyle { OutlineCapsuleStyle(prominent: true) }
}

extension ToolbarContent {
    /// iOS 26+ wraps each toolbar button in grey glass; without it the button's own capsule shows.
    @ToolbarContentBuilder func withoutGlass() -> some ToolbarContent {
        if #available(iOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

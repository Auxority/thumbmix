import SwiftUI

/// A near-black capsule for the buttons iOS would fill grey (toolbar glass, Connect), so the screen stays OLED dark.
/// iOS 26+ gets glass tinted black, which keeps the system's rim and press effect and sits with its back button;
/// older iOS has no glass, so a black fill with a thin edge. A prominent button fills white while enabled.
struct DarkCapsuleStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .foregroundStyle(isFilled ? Color.black : isEnabled ? Color.white : Theme.secondaryText)
        // iOS 27's bar measured the capsule too narrow ("D…" for Disconnect), as it did the DEMO pill.
        if #available(iOS 26, *) {
            label.glassEffect(.regular.tint(isFilled ? .white : .black).interactive(), in: Capsule()).fixedSize()
        } else {
            label
                .background(isFilled ? Color.white : Theme.background, in: Capsule())
                .overlay { Capsule().strokeBorder(isFilled ? Color.clear : Theme.outline, lineWidth: 1) }
                .opacity(configuration.isPressed ? 0.5 : 1)
                .contentShape(Capsule())
                .fixedSize()
        }
    }

    private var isFilled: Bool { prominent && isEnabled }
}

extension ButtonStyle where Self == DarkCapsuleStyle {
    static var darkCapsule: DarkCapsuleStyle { DarkCapsuleStyle() }
    static var prominentDarkCapsule: DarkCapsuleStyle { DarkCapsuleStyle(prominent: true) }
}

extension ToolbarContent {
    /// iOS 26+ wraps each toolbar button in its own grey glass; hiding it lets the button's dark capsule show.
    @ToolbarContentBuilder func withoutSharedGlass() -> some ToolbarContent {
        if #available(iOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

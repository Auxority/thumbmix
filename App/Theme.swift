import SwiftUI
import ThumbmixCore

/// Pure black for OLED; console colours are the only saturated colours on screen.
enum Theme {
    static let background = Color.black
    static let track = Color(white: 0.11)
    static let raised = Color(white: 0.18)
    static let secondaryText = Color(white: 0.6)
    static let muteRed = Color(red: 0.95, green: 0.2, blue: 0.2)
    /// EQ, Gate and Comp graphs share one size, so switching tabs never resizes the plot (layout A, 2026-10-17).
    static let graphHeight: CGFloat = 190
    /// Picked for flipped polarity (DECISIONS.md: amber, not red), apart from `soloYellow`; they only happen to match today.
    static let polarityAmber = Color(red: 1, green: 0.84, blue: 0.04)
    /// The desk's solo buttons light yellow.
    static let soloYellow = Color(red: 1, green: 0.84, blue: 0.04)
    /// A state that's on almost all show (in the main mix) is tinted, not filled: fills mean "look here" (solo,
    /// mute). Green on the tint is 6.1:1.
    static let usualOnTint = Color(red: 18 / 255, green: 61 / 255, blue: 32 / 255)
    static let usualOnGreen = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
    /// Muted by a mute group, and a group that's on: a `muteRed` border on this tint, not a fill, which is the strip's
    /// own MUTE (pick "2", 2026-10-19). The text on the tint is 5.9:1.
    static let groupMuteTint = Color(red: 58 / 255, green: 20 / 255, blue: 20 / 255)
    static let groupMuteText = Color(red: 1, green: 107 / 255, blue: 107 / 255)
    /// Off text on `raised`, 6.3:1; `secondaryText` there is only 4.3:1, under AA for 15 pt.
    static let offText = Color(white: 0.69)
    static let demoPurple = Color(red: 0.6, green: 0.3, blue: 0.85)

    /// Inverted scribble strips get their base colour: the inversion is an LCD effect, not a different colour. `Stripe`
    /// draws it as an outline.
    static func color(_ console: ConsoleColor) -> Color {
        switch console.base {
        case .off: Color(white: 0.35)
        case .red: Color(red: 0.95, green: 0.25, blue: 0.25)
        case .green: Color(red: 0.3, green: 0.85, blue: 0.35)
        case .yellow: Color(red: 0.98, green: 0.85, blue: 0.2)
        case .blue: Color(red: 0.3, green: 0.5, blue: 1.0)
        case .magenta: Color(red: 0.9, green: 0.35, blue: 0.9)
        case .cyan: Color(red: 0.25, green: 0.85, blue: 0.95)
        case .white: Color(white: 0.95)
        }
    }
}

extension Theme {
    /// A disabled control's opacity.
    static let dimmedOpacity = 0.38
    /// A strip's colour behind its row, over `track`: a slider row's fill at rest, a Members name block.
    static let accentTintOpacity = 0.28
}

/// Disables a control until the console sent its value and dims it like a disabled `ParameterRow`: an unread
/// control in full grey would still read as a real "Off".
private struct DimmedUntilRead: ViewModifier {
    let isRead: Bool
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .disabled(!isRead)
            .opacity(isEnabled && isRead ? 1 : Theme.dimmedOpacity)
    }
}

extension View {
    func dimmedUntilRead(_ isRead: Bool) -> some View { modifier(DimmedUntilRead(isRead: isRead)) }

    /// A section's small grey caps title on a strip tab ("KEY", "INSERT", "TAP POINT").
    func sectionLabel() -> some View {
        font(.footnote).textCase(.uppercase).foregroundStyle(Theme.secondaryText)
    }
}

import SwiftUI
import ThumbmixCore

/// Pure black for OLED; console colours are the only saturated colours on screen.
enum Theme {
    static let background = Color.black
    static let track = Color(white: 0.11)
    static let raised = Color(white: 0.18)
    static let selected = Color(white: 0.3)
    static let secondaryText = Color(white: 0.6)
    static let muteRed = Color(red: 0.95, green: 0.2, blue: 0.2)

    /// Inverted scribble strips get their base colour: the inversion is an LCD effect, not a different colour.
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

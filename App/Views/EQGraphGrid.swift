import SwiftUI
import ThumbmixCore

/// The EQ graph's scale: gain lines every 6 dB and the 100 Hz, 1 kHz and 10 kHz lines, with their numbers
/// (2026-10-22, A1t): frequencies along the top, where the low cut and the glow rarely reach.
enum EQGraphGrid {
    /// The y axis, from the top: +15 dB at 0, -15 dB at 1.
    static func y(decibels: Double) -> Double { 1 - (min(max(decibels, -15), 15) + 15) / 30 }

    static func draw(in context: GraphicsContext, size: CGSize) {
        var grid = Path()
        for (decibels, text) in [(-12.0, "−12"), (-6, "−6"), (0, ""), (6, "+6"), (12, "+12")] {
            let lineY = y(decibels: decibels) * size.height
            grid.move(to: CGPoint(x: 0, y: lineY))
            grid.addLine(to: CGPoint(x: size.width, y: lineY))
            context.draw(number(text), at: CGPoint(x: 4, y: lineY - 1), anchor: .bottomLeading)
        }
        for (hertz, text) in [(100.0, "100"), (1000, "1k"), (10_000, "10k")] {
            let x = EQAxis.position(hertz: hertz) * size.width
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            context.draw(number(text), at: CGPoint(x: x + 3, y: 4), anchor: .topLeading)
        }
        context.stroke(grid, with: .color(Theme.raised), lineWidth: 1)
    }

    private static func number(_ text: String) -> Text {
        Text(verbatim: text).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.secondaryText)
    }
}

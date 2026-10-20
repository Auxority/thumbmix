import SwiftUI
import ThumbmixCore

/// The desk's RTA for this channel, after its EQ: a glow in the channel's colour behind the EQ curve.
/// It has its own scale, -90 dBFS at the bottom to 0 at the top, independent of the curve's ±15 dB.
/// Reads the spectrum cell itself, so 20 Hz updates redraw only the glow.
struct SpectrumGlow: View {
    static let floor = -90.0

    let spectrum: SpectrumCell
    let color: Color
    /// The key graph's filter (dB at a frequency): the glow is bright only where the filter lets the sound through,
    /// and the whole spectrum shows dimmed behind it (2026-10-20).
    var filter: ((Double) -> Double)?

    var body: some View {
        let decibels = spectrum.decibels
        Canvas { context, size in
            guard decibels.count > 1 else { return }
            guard let filter else { return draw(decibels, strength: 1, in: context, size: size) }
            draw(decibels, strength: 0.3, in: context, size: size)
            draw(RTA.filtered(decibels, by: filter), strength: 1, in: context, size: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ decibels: [Float], strength: Double, in context: GraphicsContext, size: CGSize) {
        let outline = Self.outline(decibels, in: size)
        var area = outline
        area.addLine(to: CGPoint(x: size.width, y: size.height))
        area.addLine(to: CGPoint(x: 0, y: size.height))
        area.closeSubpath()
        let fade = Gradient(colors: [color.opacity(0.5 * strength), color.opacity(0)])
        context.fill(area, with: .linearGradient(fade, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        context.stroke(outline, with: .color(color.opacity(0.85 * strength)), lineWidth: 1)
    }

    /// x follows the EQ graph's log 20 Hz-20 kHz axis, so a peak sits under the band that shapes it.
    private static func outline(_ decibels: [Float], in size: CGSize) -> Path {
        var path = Path()
        for (band, level) in decibels.enumerated() {
            let x = EQAxis.position(hertz: RTA.bandFrequency(band)) * size.width
            let fraction = (min(max(Double(level), floor), 0) - floor) / -floor
            let point = CGPoint(x: x, y: (1 - fraction) * size.height)
            if band == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// Says the desk's RTA is borrowed only once spectrum data actually arrives. The line is always there: appearing
/// with the first data, it pushed the rows under it down a line just after the tab opened.
struct RTAStatus: View {
    let spectrum: SpectrumCell
    let name: String
    /// A gate's key is heard before the EQ (2026-10-20): the line says which the glow shows.
    var afterEQ = true

    var body: some View {
        Group {
            if spectrum.decibels.isEmpty {
                Text("RTA: waiting for the desk…")
            } else if afterEQ {
                Text("RTA follows \(name) (after EQ)")
            } else {
                Text("RTA follows \(name) (before EQ)")
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.secondaryText)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("rta-status")
    }
}

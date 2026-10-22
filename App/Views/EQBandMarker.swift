import SwiftUI

/// An EQ graph point (2026-10-22, mock T4 in `notes/mocks/2026-10-22-eq-graph/`): a dot exactly on the band's value,
/// so the curve shows through, and its number in a frosted tag on a short stem, placed by `EQTagLayout`.
struct EQBandPlace: Equatable {
    let dot: CGPoint
    let tag: CGPoint
}

struct EQBandDot: View {
    let at: CGPoint
    let isSelected: Bool
    let tint: Color

    var body: some View {
        Circle().fill(tint).frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6).position(at)
            .allowsHitTesting(false)
    }
}

/// The stem from the dot and the tag. Selected: solid, lifted by a shadow. Otherwise frosted, on a disc of the card's
/// colour so the curve behind it never runs through the number.
struct EQBandTag: View {
    let label: String
    let dot: CGPoint
    let tag: CGPoint
    let isSelected: Bool
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Stem(from: dot, to: tag).stroke(isSelected ? tint : tint.opacity(0.5), lineWidth: 1)
            ZStack {
                if isSelected {
                    Circle().fill(tint).shadow(color: .black.opacity(0.6), radius: 4, y: 1)
                } else {
                    Circle().fill(Theme.track)
                    Circle().fill(tint.opacity(0.18))
                    Circle().stroke(tint.opacity(0.5), lineWidth: 1)
                }
                Text(label).font(.caption2.bold()).minimumScaleFactor(0.5).lineLimit(1)
                    .foregroundStyle(isSelected ? .black : tint)
            }
            .frame(width: size, height: size)
            .position(tag)
        }
        .allowsHitTesting(false)
    }
}

/// A line whose tag end animates as the tag slides aside; the dot end follows the dot at once, like the dot itself.
private struct Stem: Shape {
    let from: CGPoint
    var to: CGPoint

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(to.x, to.y) }
        set { to = CGPoint(x: newValue.first, y: newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
    }
}

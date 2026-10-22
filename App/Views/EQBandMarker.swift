import SwiftUI

/// An EQ graph point (2026-10-22, mock T4 in `notes/mocks/2026-10-22-eq-graph/`): a dot exactly on the band's value,
/// so the curve shows through, and its number in a frosted tag on a short stem, placed by `EQTagLayout`.
struct EQBandMarker: View {
    struct Place: Equatable {
        let dot: CGPoint
        let tag: CGPoint
    }

    let label: String
    let dot: CGPoint
    let tag: CGPoint
    let isSelected: Bool
    /// White for bands, the low cut's yellow for L.
    let tint: Color
    let tagSize: CGFloat

    var body: some View {
        ZStack {
            Stem(from: dot, to: tag).stroke(isSelected ? tint : tint.opacity(0.5), lineWidth: 1)
            Circle().fill(tint).frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6).position(dot)
            BandTag(label: label, isSelected: isSelected, tint: tint, size: tagSize).position(tag)
        }
        .allowsHitTesting(false)
    }
}

/// Selected: solid, lifted by a shadow. Otherwise frosted, on a disc of the card's colour so the curve behind it
/// never runs through the number.
private struct BandTag: View {
    let label: String
    let isSelected: Bool
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(tint).shadow(color: .black.opacity(0.6), radius: 4, y: 1)
            } else {
                Circle().fill(Theme.track)
                Circle().fill(tint.opacity(0.18))
                Circle().stroke(tint.opacity(0.5), lineWidth: 1)
            }
            Text(label).font(.caption2.bold()).foregroundStyle(isSelected ? .black : tint)
        }
        .frame(width: size, height: size)
    }
}

/// A line whose ends animate, so a stem follows its tag while the tag slides aside.
private struct Stem: Shape {
    var from: CGPoint
    var to: CGPoint

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(from.x, from.y), AnimatablePair(to.x, to.y)) }
        set {
            from = CGPoint(x: newValue.first.first, y: newValue.first.second)
            to = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
    }
}

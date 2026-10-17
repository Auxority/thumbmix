import SwiftUI
import ThumbmixCore

/// One overview row: a strip, or a linked pair driven by its odd side's fader and mute (the desk copies them).
struct StripRow: View {
    let item: OverviewItem
    let mirror: ConsoleMirror
    let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric private var nameWidth: CGFloat = 78

    var body: some View {
        // At accessibility text sizes a 375 pt row can't fit name, fader and mute side by side.
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                nameButton
                HStack(spacing: 8) { faderAndMute }
            }
        } else {
            HStack(spacing: 8) {
                nameButton.frame(width: nameWidth + 14, alignment: .leading)
                faderAndMute
            }
        }
    }

    private var strip: StripID { item.held }

    private var color: Color { Theme.color(mirror.color(strip)) }

    private var name: String { mirror.title(of: item) }

    /// The number printed on the desk, both numbers for a pair; the mains have none.
    private var number: String {
        if case .pair(let odd) = item { return "\(odd.number)-\(odd.number + 1)" }
        return [.mainStereo, .mainMono].contains(strip.kind) ? "" : "\(strip.number)"
    }

    private var nameButton: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                stripe
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if !number.isEmpty {
                        Text(number).font(.caption2).foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(number)
    }

    /// A pair's stripe is cut in two: top for the odd (left) side, bottom for the even (right) side, each in its own colour.
    @ViewBuilder private var stripe: some View {
        switch item {
        case .strip(_, .full):
            Stripe(mirror.color(strip)).frame(width: 6, height: 40)
        case .strip(_, let half):
            let console = mirror.color(strip)
            StackedStripe(
                top: Stripe(console, opacity: half == .top ? 1 : 0.25),
                bottom: Stripe(console, opacity: half == .bottom ? 1 : 0.25))
        case .pair(let odd):
            StackedStripe(top: Stripe(mirror.color(strip)), bottom: Stripe(mirror.color(odd.partner ?? odd)))
        }
    }

    @ViewBuilder private var faderAndMute: some View {
        ParameterRow(
            spec: Catalog.fader(strip), mirror: mirror, title: "", accent: color, height: 52,
            meter: mirror.meter(rightSide ?? strip), upperMeter: rightSide.map { _ in mirror.meter(strip) }
        )
        .accessibilityLabel("\(name) fader")
        MuteButton(strip: strip, mirror: mirror, height: 52)
    }

    /// The even side of a pair row, whose meter runs under the odd side's.
    private var rightSide: StripID? {
        if case .pair(let odd) = item { return odd.partner }
        return nil
    }
}

struct StackedStripe: View {
    let top: Stripe
    let bottom: Stripe
    var width: CGFloat = 6
    var height: CGFloat = 40

    var body: some View {
        VStack(spacing: 3) {
            top
            bottom
        }
        .frame(width: width, height: height)
    }
}

/// A strip's colour as the desk shows it: filled, or outlined in the colour when inverted (II, 2026-10-17).
struct Stripe: View {
    let color: Color
    let inverted: Bool
    let cornerRadius: CGFloat

    init(_ console: ConsoleColor, opacity: Double = 1, cornerRadius: CGFloat = 3) {
        color = Theme.color(console).opacity(opacity)
        inverted = console.inverted
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if inverted {
            shape.strokeBorder(color, lineWidth: 2)
        } else {
            shape.fill(color)
        }
    }
}

#if DEBUG
    #Preview {
        let mirror = ConsoleMirror.preview()
        return VStack(spacing: 6) {
            ForEach(mirror.overviewItems(StripID.all(.input), showUnused: true)) { StripRow(item: $0, mirror: mirror) {} }
        }
        .padding(12)
        .background(Theme.background)
    }
#endif

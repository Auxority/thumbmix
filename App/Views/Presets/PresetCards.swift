import SwiftUI
import ThumbmixCore

/// One part of a preset on its page (round 4, 2026-10-28): its picture beside the few values that change a sound most.
/// The picture shows what the part *is*, whatever its switch holds; a part saved off says so in its first line.
struct PresetCard: View {
    let preset: Preset
    let part: PresetPart
    let mirror: ConsoleMirror

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: part.title).font(.headline)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            }
            HStack(alignment: .center, spacing: 12) {
                PresetPicture(preset: preset, part: part, size: .card)
                PresetLines(lines: PresetSummary.overview(preset, part), mirror: mirror)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("preset-part-" + part.rawValue)
    }
}

/// Label on the left, value on the right; a send's bus gets the name the desk gives it now, since a send loads by
/// number: "Bus 1 · Wedge DS".
private struct PresetLines: View {
    let lines: [PresetLine]
    let mirror: ConsoleMirror

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: 6) {
                    Text(verbatim: label(line)).foregroundStyle(Theme.secondaryText).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(verbatim: line.value).fontWeight(.semibold).monospacedDigit().lineLimit(1)
                }
                .font(.subheadline)
            }
        }
    }

    private func label(_ line: PresetLine) -> String {
        guard let bus = line.bus else { return line.label }
        return PresetBusName.label(line.label, bus, mirror)
    }
}

/// The desk's current name for a bus, only while the desk is live and only where it differs from "Bus 3".
@MainActor
enum PresetBusName {
    static func label(_ label: String, _ bus: StripID, _ mirror: ConsoleMirror) -> String {
        let name = mirror.name(bus)
        guard mirror.isLive, name != bus.defaultName else { return label }
        return label + " · " + name
    }
}

/// A part's picture: the EQ curve, the gate's or comp's transfer curve, the Mix's fader and pan. Input and Sends have
/// none: their values are the picture.
struct PresetPicture: View {
    enum Size { case card, page }

    let preset: Preset
    let part: PresetPart
    let size: Size

    var body: some View {
        switch part {
        case .eq:
            PresetSummary.eqCurve(preset).map { curve in
                plot(PresetEQCurve(bands: curve.bands, lowCut: curve.lowCut, numbers: size == .page), wide: true)
            }
        case .gate: PresetSummary.gateCurve(preset).map { plot(TransferPlot(curve: Self.curve($0.output, $0.threshold))) }
        case .comp: PresetSummary.compCurve(preset).map { plot(TransferPlot(curve: Self.curve($0.output, $0.threshold))) }
        case .mix: PresetSummary.mixPosition(preset).map { plot(MixPicture(fader: $0.fader, pan: $0.pan), wide: true) }
        case .input, .sends: EmptyView()
        }
    }

    /// On, so the curve drawn is the one the preset holds.
    private static func curve(_ output: @escaping (Double) -> Double, _ threshold: Double) -> TransferPlot.Curve {
        TransferPlot.Curve(output: output, threshold: threshold, isOn: true)
    }

    private func plot(_ content: some View, wide: Bool = false) -> some View {
        let height: CGFloat = size == .card ? 76 : wide ? 120 : 150
        return
            content
            .frame(width: wide ? (size == .card ? 170 : nil) : height, height: height)
            .frame(maxWidth: size == .page && wide ? .infinity : nil)
            .background(size == .card ? Color.black.opacity(0.35) : Theme.track, in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}

/// The EQ curve of a preset, read-only: the same grid as the EQ tab's graph, the low cut in yellow.
struct PresetEQCurve: View {
    let bands: [EQBandState]
    let lowCut: LowCutState?
    var numbers = true

    var body: some View {
        Canvas { context, size in
            EQGraphGrid.draw(in: context, size: size, numbers: numbers)
            context.stroke(EQGraphGrid.curve(bands, lowCut, in: size), with: .color(.white), lineWidth: 2)
            if let lowCut {
                context.stroke(
                    EQGraphGrid.curve(bands, lowCut, in: size, upTo: lowCut.frequency * 2), with: .color(EQGraph.lowCutColor),
                    lineWidth: 3)
            }
        }
    }
}

/// The fader on its dB scale, the pan under it (round 5, 2026-10-28). The ticks sit where the desk's fader law puts
/// them: −30, −10 and 0 dB at a quarter, half and three quarters of the throw.
private struct MixPicture: View {
    let fader: Double
    let pan: Double
    private static let ticks: [(Double, String)] = [(0, "−∞"), (0.25, "−30"), (0.5, "−10"), (0.75, "0"), (1, "+10")]

    var body: some View {
        Canvas { context, size in
            let left = 12.0
            let width = size.width - 2 * left
            let faderY = size.height * 0.3
            let panY = size.height * 0.75
            track(in: context, y: faderY, from: left, to: left + width, filledTo: left + width * fader)
            context.fill(
                Path(roundedRect: CGRect(x: left + width * fader - 6, y: faderY - 9, width: 12, height: 18), cornerRadius: 3),
                with: .color(.white))
            for (at, label) in Self.ticks {
                context.draw(
                    Text(verbatim: label).font(.system(size: 9)).foregroundStyle(Theme.secondaryText),
                    at: CGPoint(x: left + width * at, y: faderY + 17))
            }
            let centre = left + width / 2
            track(in: context, y: panY, from: left, to: left + width, filledTo: nil)
            stroke(context, from: centre, to: centre + width / 2 * pan, y: panY)
            context.fill(Path(ellipseIn: CGRect(x: centre + width / 2 * pan - 5, y: panY - 5, width: 10, height: 10)), with: .color(.white))
            for (x, label) in [(left, "L"), (centre, "C"), (left + width, "R")] {
                context.draw(
                    Text(verbatim: label).font(.system(size: 9)).foregroundStyle(Theme.secondaryText), at: CGPoint(x: x, y: panY + 13))
            }
        }
    }

    private func track(in context: GraphicsContext, y: Double, from start: Double, to end: Double, filledTo fill: Double?) {
        stroke(context, from: start, to: end, y: y, color: Theme.raised)
        if let fill { stroke(context, from: start, to: fill, y: y) }
    }

    private func stroke(_ context: GraphicsContext, from start: Double, to end: Double, y: Double, color: Color = .white) {
        var line = Path()
        line.move(to: CGPoint(x: start, y: y))
        line.addLine(to: CGPoint(x: end, y: y))
        context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }
}

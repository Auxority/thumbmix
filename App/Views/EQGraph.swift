import SwiftUI
import ThumbmixCore

/// x = frequency (log 20 Hz-20 kHz), y = gain (±15 dB). Both match the parameters' own 0...1
/// positions, so a band point's position *is* its normalized value.
struct EQGraph: View {
    /// Selection 0 is the low cut, both in the band picker and among the graph's points.
    static let lowCutBand = 0
    static let lowCutColor = Color.yellow

    let strip: StripID
    let mirror: ConsoleMirror
    @Binding var selectedBand: Int
    @State private var grab: Grab?
    @State private var isDragging = false

    /// The point under the finger and where it was at touch-down, as graph position (0...1). Drags move it
    /// by the finger's travel, like `ParameterRow`, so landing beside the point never jumps the desk.
    private struct Grab {
        let band: Int
        let x: Float
        let y: Float
    }
    @State private var pinchStartQ: Float?

    var body: some View {
        // Read the bands here, not inside Canvas: Observation only tracks reads made during body.
        let bands = mirror.eqBands(strip)
        let lowCut = mirror.lowCut(strip)
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Canvas { context, canvasSize in drawGrid(in: context, size: canvasSize) }
                SpectrumGlow(spectrum: mirror.spectrum, color: Theme.color(mirror.color(strip)))
                Canvas { context, canvasSize in
                    context.stroke(curve(bands, lowCut, in: canvasSize), with: .color(.white), lineWidth: 2)
                    if let lowCut {
                        let cutPart = curve(bands, lowCut, in: canvasSize, upTo: lowCut.frequency * 2)
                        context.stroke(cutPart, with: .color(Self.lowCutColor), lineWidth: 3)
                    }
                }
                ForEach(points, id: \.self) { band in
                    BandPoint(
                        label: band == Self.lowCutBand ? "L" : "\(band)", isSelected: band == selectedBand,
                        tint: band == Self.lowCutBand && lowCut != nil ? Self.lowCutColor : nil
                    )
                    .position(position(of: band, in: size))
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: size))
            .simultaneousGesture(pinchGesture)
            .simultaneousGesture(resetGesture(in: size))
        }
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("eq-graph")
        .accessibilityLabel("EQ curve")
    }

    private var points: [Int] {
        (Catalog.lowCut(strip) == nil ? [] : [Self.lowCutBand]) + Array(1...strip.eqBandCount)
    }

    private func position(of band: Int, in size: CGSize) -> CGPoint {
        guard band != Self.lowCutBand else { return lowCutPosition(in: size) }
        let specs = Catalog.eqBand(strip, band)
        let x = CGFloat(mirror.normalized(specs.frequency) ?? 0.5) * size.width
        let y = (1 - CGFloat(mirror.normalized(specs.gain) ?? 0.5)) * size.height
        return CGPoint(x: x, y: y)
    }

    /// The "L" point sits at the cutoff on the -3 dB line, where the filter starts to bite.
    private func lowCutPosition(in size: CGSize) -> CGPoint {
        let x = CGFloat(Self.graphX(hertz: lowCutHertz ?? 100)) * size.width
        return CGPoint(x: x, y: (1 - (-3 + 15) / 30) * size.height)
    }

    private var lowCutHertz: Double? {
        guard let frequency = Catalog.lowCut(strip)?.frequency, let position = mirror.normalized(frequency) else {
            return nil
        }
        return frequency.scale.value(fromNormalized: position)
    }

    /// The graph's x axis is log 20 Hz-20 kHz, the same law as the band frequency parameter.
    private static func graphX(hertz: Double) -> Double { log(hertz / 20) / log(1000) }

    private func curve(_ bands: [EQBandState], _ lowCut: LowCutState?, in size: CGSize, upTo maxHertz: Double = 20_000)
        -> Path
    {
        var path = Path()
        let lastX = min(Self.graphX(hertz: maxHertz), 1)
        for step in 0...120 {
            let x = Double(step) / 120 * lastX
            let hertz = 20 * pow(1000, x)
            let decibels = EQResponse.decibels(at: hertz, bands: bands) + (lowCut?.decibels(at: hertz) ?? 0)
            let point = CGPoint(
                x: x * size.width, y: (1 - (min(max(decibels, -15), 15) + 15) / 30) * size.height)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private func drawGrid(in context: GraphicsContext, size: CGSize) {
        var grid = Path()
        for decibels in [-12.0, -6, 0, 6, 12] {
            let y = (1 - (decibels + 15) / 30) * size.height
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        for hertz in [100.0, 1000, 10_000] {
            let x = log(hertz / 20) / log(1000) * size.width
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        context.stroke(grid, with: .color(Theme.raised), lineWidth: 1)
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    grab = startGrab(at: value.startLocation, in: size)
                }
                guard let grab, value.translation != .zero else { return }
                move(grab, by: value.translation, in: size)
            }
            .onEnded { _ in
                if let grab { pointAddresses(of: grab.band).forEach(mirror.endEdit) }
                isDragging = false
                grab = nil
            }
    }

    /// nil when no point is near, or the band's values were never read: then the touch changes nothing.
    private func startGrab(at point: CGPoint, in size: CGSize) -> Grab? {
        guard let band = nearestBand(to: point, in: size), let origin = graphPosition(of: band) else { return nil }
        selectedBand = band
        pointAddresses(of: band).forEach(mirror.beginEdit)
        return Grab(band: band, x: origin.x, y: origin.y)
    }

    /// Where a point is on the graph (0...1), from values the desk sent; nil if any was never read.
    private func graphPosition(of band: Int) -> (x: Float, y: Float)? {
        if band == Self.lowCutBand { return lowCutHertz.map { (Float(Self.graphX(hertz: $0)), 0) } }
        let specs = Catalog.eqBand(strip, band)
        guard let frequency = mirror.normalized(specs.frequency), let gain = mirror.normalized(specs.gain) else {
            return nil
        }
        return (frequency, gain)
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // The low cut has no Q.
                guard selectedBand != Self.lowCutBand else { return }
                let q = Catalog.eqBand(strip, selectedBand).q
                if pinchStartQ == nil {
                    guard let current = mirror.normalized(q) else { return }
                    pinchStartQ = current
                    mirror.beginEdit(q.address)
                }
                // Spreading the fingers widens the band; on the M32's Q scale, wider is a higher position.
                let next = (pinchStartQ ?? 0.5) + Float(log2(value.magnification)) * 0.25
                mirror.set(q.address, q.scale.argument(fromNormalized: next))
            }
            .onEnded { _ in
                if pinchStartQ != nil, selectedBand != Self.lowCutBand {
                    mirror.endEdit(Catalog.eqBand(strip, selectedBand).q.address)
                }
                pinchStartQ = nil
            }
    }

    /// Double-tap a band point to put that band back to its default, like double-tapping a row.
    private func resetGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2).onEnded { value in
            guard let band = nearestBand(to: value.location, in: size) else { return }
            selectedBand = band
            mirror.resetEQBand(strip, band)
        }
    }

    private func pointAddresses(of band: Int) -> [String] {
        if band == Self.lowCutBand { return Catalog.lowCut(strip).map { [$0.frequency.address] } ?? [] }
        let specs = Catalog.eqBand(strip, band)
        return [specs.frequency.address, specs.gain.address]
    }

    /// Only a touch near a point grabs it, so a stray touch on the graph changes nothing.
    private func nearestBand(to point: CGPoint, in size: CGSize) -> Int? {
        let distances = points.map { band -> (Int, CGFloat) in
            let p = position(of: band, in: size)
            return (band, hypot(p.x - point.x, p.y - point.y))
        }
        guard let nearest = distances.min(by: { $0.1 < $1.1 }), nearest.1 < 44 else { return nil }
        return nearest.0
    }

    private func move(_ grab: Grab, by translation: CGSize, in size: CGSize) {
        let x = grab.x + Float(translation.width / size.width)
        guard grab.band != Self.lowCutBand else { return moveLowCut(toGraphX: x) }
        let specs = Catalog.eqBand(strip, grab.band)
        mirror.set(specs.frequency.address, specs.frequency.scale.argument(fromNormalized: x))
        // Cut filters and the main-bus crossover types have no gain, so vertical movement is ignored.
        let type = Int(specs.type.scale.value(fromNormalized: mirror.normalized(specs.type) ?? 0))
        guard [1, 2, 3, 4].contains(type) else { return }
        let y = grab.y - Float(translation.height / size.height)
        mirror.set(specs.gain.address, specs.gain.scale.argument(fromNormalized: y))
    }

    /// The low cut only moves sideways; its 20-400 Hz scale clamps a drag past either end.
    private func moveLowCut(toGraphX x: Float) {
        guard let frequency = Catalog.lowCut(strip)?.frequency else { return }
        let hertz = 20 * pow(1000, Double(x))
        mirror.set(frequency.address, frequency.scale.argument(fromNormalized: frequency.scale.normalized(forValue: hertz)))
    }
}

private struct BandPoint: View {
    let label: String
    let isSelected: Bool
    /// The low cut's colour while it is on; bands use the selection colours.
    var tint: Color?
    @ScaledMetric private var size: CGFloat = 28

    var body: some View {
        Circle()
            .fill(tint ?? (isSelected ? Color.white : Theme.raised))
            .frame(width: size, height: size)
            .overlay(Circle().stroke(.white, lineWidth: isSelected && tint != nil ? 2 : 0))
            .overlay(Text(label).font(.caption.bold()).foregroundStyle(isSelected || tint != nil ? .black : .white))
    }
}

import SwiftUI
import ThumbmixCore

struct EQTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var band = 1

    var body: some View {
        VStack(spacing: 8) {
            EQGraph(strip: strip, mirror: mirror, selectedBand: $band)
                .frame(height: 190)
            HStack(spacing: 8) {
                ToggleChip(spec: Catalog.eqOn(strip), mirror: mirror, onColor: .green)
                Picker("Band", selection: $band) {
                    ForEach(1...strip.eqBandCount, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Catalog.eqBand(strip, band).all) { ParameterRow(spec: $0, mirror: mirror) }
                }
            }
        }
    }
}

/// x = frequency (log 20 Hz-20 kHz), y = gain (±15 dB). Both match the parameters' own 0...1
/// positions, so a band point's position *is* its normalized value.
struct EQGraph: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @Binding var selectedBand: Int
    @State private var draggedBand: Int?
    @State private var isDragging = false
    @State private var pinchStartQ: Float?

    var body: some View {
        // Read the bands here, not inside Canvas: Observation only tracks reads made during body.
        let bands = mirror.eqBands(strip)
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Canvas { context, canvasSize in
                    drawGrid(in: context, size: canvasSize)
                    context.stroke(curve(bands, in: canvasSize), with: .color(.white), lineWidth: 2)
                }
                ForEach(1...strip.eqBandCount, id: \.self) { band in
                    BandPoint(number: band, isSelected: band == selectedBand)
                        .position(position(of: band, in: size))
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: size))
            .simultaneousGesture(pinchGesture)
        }
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("eq-graph")
        .accessibilityLabel("EQ curve")
    }

    private func position(of band: Int, in size: CGSize) -> CGPoint {
        let specs = Catalog.eqBand(strip, band)
        let x = CGFloat(mirror.normalized(specs.frequency) ?? 0.5) * size.width
        let y = (1 - CGFloat(mirror.normalized(specs.gain) ?? 0.5)) * size.height
        return CGPoint(x: x, y: y)
    }

    private func curve(_ bands: [EQBandState], in size: CGSize) -> Path {
        var path = Path()
        for step in 0...120 {
            let x = Double(step) / 120
            let decibels = EQResponse.decibels(at: 20 * pow(1000, x), bands: bands)
            let point = CGPoint(x: x * size.width, y: (1 - (min(max(decibels, -15), 15) + 15) / 30) * size.height)
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
                    draggedBand = nearestBand(to: value.startLocation, in: size)
                    if let draggedBand {
                        selectedBand = draggedBand
                        pointAddresses(of: draggedBand).forEach(mirror.beginEdit)
                    }
                }
                guard let draggedBand else { return }
                move(band: draggedBand, to: value.location, in: size)
            }
            .onEnded { _ in
                if let draggedBand { pointAddresses(of: draggedBand).forEach(mirror.endEdit) }
                isDragging = false
                draggedBand = nil
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
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
                if pinchStartQ != nil { mirror.endEdit(Catalog.eqBand(strip, selectedBand).q.address) }
                pinchStartQ = nil
            }
    }

    private func pointAddresses(of band: Int) -> [String] {
        let specs = Catalog.eqBand(strip, band)
        return [specs.frequency.address, specs.gain.address]
    }

    /// Only a touch near a point grabs it, so a stray touch on the graph changes nothing.
    private func nearestBand(to point: CGPoint, in size: CGSize) -> Int? {
        let distances = (1...strip.eqBandCount).map { band -> (Int, CGFloat) in
            let p = position(of: band, in: size)
            return (band, hypot(p.x - point.x, p.y - point.y))
        }
        guard let nearest = distances.min(by: { $0.1 < $1.1 }), nearest.1 < 44 else { return nil }
        return nearest.0
    }

    private func move(band: Int, to point: CGPoint, in size: CGSize) {
        let specs = Catalog.eqBand(strip, band)
        let x = Float(min(max(point.x / size.width, 0), 1))
        mirror.set(specs.frequency.address, specs.frequency.scale.argument(fromNormalized: x))
        // Cut filters and the main-bus crossover types have no gain, so vertical movement is ignored.
        let type = Int(specs.type.scale.value(fromNormalized: mirror.normalized(specs.type) ?? 0))
        guard [1, 2, 3, 4].contains(type) else { return }
        let y = Float(1 - min(max(point.y / size.height, 0), 1))
        mirror.set(specs.gain.address, specs.gain.scale.argument(fromNormalized: y))
    }
}

private struct BandPoint: View {
    let number: Int
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(isSelected ? Color.white : Theme.raised)
            .frame(width: 28, height: 28)
            .overlay(Text("\(number)").font(.caption.bold()).foregroundStyle(isSelected ? .black : .white))
    }
}

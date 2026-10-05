import SwiftUI
import ThumbmixCore

struct EQTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var band = 1
    @State private var isConfirmingReset = false

    var body: some View {
        let specs = Catalog.eqBand(strip, band)
        // One scroll view for the whole tab: a fixed graph left the rows a sliver of their own to scroll in.
        ScrollView {
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
                ChoiceMenu(spec: specs.type, mirror: mirror)
                ForEach([specs.frequency, specs.gain, specs.q]) { ParameterRow(spec: $0, mirror: mirror) }
                if let defaults = Catalog.eqDefaults(strip) { resetButton(bandCount: defaults.count) }
            }
        }
    }

    /// Resetting rewrites every band on the desk at once, so it asks first.
    private func resetButton(bandCount: Int) -> some View {
        Button("Reset bands", role: .destructive) { isConfirmingReset = true }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
            .confirmationDialog(
                "Every band goes back to PEQ at 91.4 Hz, 418 Hz, 1.91 kHz and 8.73 kHz, Q 1.7, 0 dB.",
                isPresented: $isConfirmingReset, titleVisibility: .visible
            ) {
                Button("Reset all \(bandCount) bands", role: .destructive) { mirror.resetEQBands(strip) }
                Button("Cancel", role: .cancel) {}
            }
    }
}

/// x = frequency (log 20 Hz-20 kHz), y = gain (±15 dB). Both match the parameters' own 0...1
/// positions, so a band point's position *is* its normalized value.
struct EQGraph: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @Binding var selectedBand: Int
    @State private var grab: Grab?
    @State private var isDragging = false

    /// The band under the finger and where it was at touch-down. Drags move it by the finger's travel,
    /// like `ParameterRow`, so landing beside the point never jumps the desk to the finger.
    private struct Grab {
        let band: Int
        let frequency: Float
        let gain: Float
    }
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
            .simultaneousGesture(resetGesture(in: size))
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
        guard let band = nearestBand(to: point, in: size) else { return nil }
        let specs = Catalog.eqBand(strip, band)
        guard let frequency = mirror.normalized(specs.frequency), let gain = mirror.normalized(specs.gain) else {
            return nil
        }
        selectedBand = band
        pointAddresses(of: band).forEach(mirror.beginEdit)
        return Grab(band: band, frequency: frequency, gain: gain)
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

    /// Double-tap a band point to put that band back to its default, like double-tapping a row.
    private func resetGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2).onEnded { value in
            guard let band = nearestBand(to: value.location, in: size) else { return }
            selectedBand = band
            mirror.resetEQBand(strip, band)
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

    private func move(_ grab: Grab, by translation: CGSize, in size: CGSize) {
        let specs = Catalog.eqBand(strip, grab.band)
        let x = grab.frequency + Float(translation.width / size.width)
        mirror.set(specs.frequency.address, specs.frequency.scale.argument(fromNormalized: x))
        // Cut filters and the main-bus crossover types have no gain, so vertical movement is ignored.
        let type = Int(specs.type.scale.value(fromNormalized: mirror.normalized(specs.type) ?? 0))
        guard [1, 2, 3, 4].contains(type) else { return }
        let y = grab.gain - Float(translation.height / size.height)
        mirror.set(specs.gain.address, specs.gain.scale.argument(fromNormalized: y))
    }
}

private struct BandPoint: View {
    let number: Int
    let isSelected: Bool
    @ScaledMetric private var size: CGFloat = 28

    var body: some View {
        Circle()
            .fill(isSelected ? Color.white : Theme.raised)
            .frame(width: size, height: size)
            .overlay(
                Text("\(number)").font(.caption.bold()).foregroundStyle(isSelected ? .black : .white))
    }
}

#if DEBUG
    #Preview {
        EQTab(strip: StripID(.input, 1), mirror: .preview()).padding().background(Theme.background)
    }
#endif

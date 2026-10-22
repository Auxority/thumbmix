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
    /// The other side of a pair whose EQ isn't linked: its curve is drawn faint.
    var ghost: StripID?
    @State private var grab: Grab?
    @State private var isDragging = false

    /// The point under the finger and where it was at touch-down, as graph position (0...1). Drags move it
    /// by the finger's travel, like `ParameterRow`, so landing beside the point never jumps the desk.
    private struct Grab {
        let band: Int
        let x: Float
        let y: Float
        /// The tag's place beside its dot at touch-down, kept for the whole drag.
        let pin: EQTagLayout.Pin
    }
    @State private var pinchStartQ: Float?
    @ScaledMetric(relativeTo: .caption2) private var tagSize: CGFloat = 22
    /// Reset by SwiftUI when a touch ends and also when the system cancels it (a call, Notification Center),
    /// which `onEnded` never reports: a hold left behind would keep the desk from moving the band.
    @GestureState private var isTouching = false
    @GestureState private var isPinching = false

    var body: some View {
        // Read the bands here, not inside Canvas: Observation only tracks reads made during body.
        // Off, the bands as set stay drawn, dashed and grey: what switching the EQ on brings back (2026-10-14, mock C).
        let isEQOn = mirror.isEQOn(strip)
        let bands = mirror.eqBandsAsSet(strip)
        let lowCut = mirror.lowCut(strip)
        let lowCutAsSet = mirror.lowCutAsSet(strip)
        let isLowCutOff = lowCutAsSet != nil && !mirror.isLowCutOn(strip)
        let ghostCurve = ghost.map { (bands: mirror.eqBands($0), lowCut: mirror.lowCut($0)) }
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Canvas { context, canvasSize in EQGraphGrid.draw(in: context, size: canvasSize) }
                SpectrumGlow(spectrum: mirror.spectrum, color: Theme.color(mirror.color(strip)))
                Canvas { context, canvasSize in
                    if let ghostCurve {
                        let path = curve(ghostCurve.bands, ghostCurve.lowCut, in: canvasSize)
                        context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 2)
                    }
                    context.stroke(
                        curve(bands, lowCut, in: canvasSize), with: .color(isEQOn ? .white : Theme.secondaryText),
                        style: StrokeStyle(lineWidth: 2, dash: isEQOn ? [] : [5, 4]))
                    if let lowCut {
                        // Solid yellow means live: with the EQ off it shows the cut alone, never an unheard band.
                        let heard = isEQOn ? bands : []
                        let cutPart = curve(heard, lowCut, in: canvasSize, upTo: lowCut.frequency * 2)
                        context.stroke(cutPart, with: .color(Self.lowCutColor), lineWidth: 3)
                    } else if isLowCutOff, let lowCutAsSet {
                        // Off, the cut as set is dashed like unheard bands, and ends where it would barely show, so it
                        // never runs on top of the curve (2026-10-17).
                        let end = lowCutAsSet.hertz(whereCutIs: -0.5)
                        context.stroke(
                            curve(bands, lowCutAsSet, in: canvasSize, upTo: end), with: .color(Theme.secondaryText),
                            style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    }
                }
                // Rendered offscreen at the graph's full size: drawn straight, the curve jumped 16 pt up or down for a
                // frame now and then while a band moved (iPhone 11 Pro, 2026-10-19), the grid and points staying put.
                .drawingGroup()
                let markers = markers(in: size)
                ForEach(points, id: \.self) { band in
                    EQBandTag(
                        label: band == Self.lowCutBand ? "L" : "\(band)", dot: markers[band]!.dot,
                        tag: markers[band]!.tag, isSelected: band == selectedBand, tint: tint(of: band, lowCutAsSet),
                        size: cappedTagSize
                    )
                    .opacity(isHeard(band, isEQOn: isEQOn, isLowCutOff: isLowCutOff) ? 1 : 0.5)
                    .zIndex(band == selectedBand ? 1 : 0)
                    // Tags making room slide; the dragged one follows the finger at once (2026-10-22, Q6 B).
                    .animation(band == grab?.band ? nil : .easeOut(duration: 0.2), value: markers[band]!.tag)
                }
                // Above every tag, so no tag hides a band's value; never animated, so a dot moves with the curve.
                ForEach(points, id: \.self) { band in
                    EQBandDot(at: markers[band]!.dot, isSelected: band == selectedBand, tint: tint(of: band, lowCutAsSet))
                        .opacity(isHeard(band, isEQOn: isEQOn, isLowCutOff: isLowCutOff) ? 1 : 0.5)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: size))
            .simultaneousGesture(pinchGesture)
            .simultaneousGesture(resetGesture(in: size))
        }
        .onChange(of: isTouching) { _, touching in if !touching { endGrab() } }
        .onChange(of: isPinching) { _, pinching in if !pinching { endPinch() } }
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("eq-graph")
        .accessibilityLabel("EQ curve")
        .accessibilityValue(Text(verbatim: Self.offParts(isEQOn: isEQOn, isLowCutOff: isLowCutOff)))
    }

    /// What VoiceOver hears for the parts drawn dashed: nothing while everything is on.
    private static func offParts(isEQOn: Bool, isLowCutOff: Bool) -> String {
        let parts = [isEQOn ? nil : String(localized: "EQ off"), isLowCutOff ? String(localized: "Low cut off") : nil]
        return parts.compactMap { $0 }.joined(separator: ", ")
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

    /// White for bands, the low cut's yellow for L once it is read.
    private func tint(of band: Int, _ lowCutAsSet: LowCutState?) -> Color {
        band == Self.lowCutBand && lowCutAsSet != nil ? Self.lowCutColor : .white
    }

    /// Unheard parts (an EQ or low cut that's off) show at half strength.
    private func isHeard(_ band: Int, isEQOn: Bool, isLowCutOff: Bool) -> Bool {
        band == Self.lowCutBand ? !isLowCutOff : isEQOn
    }

    /// Capped: at the largest text sizes a row of five tags would no longer fit the graph.
    private var cappedTagSize: CGFloat { min(tagSize, 30) }

    /// Each point's dot on its value and its number tag; the dragged band's tag keeps its place beside its dot.
    private func markers(in size: CGSize) -> [Int: EQBandPlace] {
        let dots = Dictionary(uniqueKeysWithValues: points.map { ($0, position(of: $0, in: size)) })
        let tags = EQTagLayout(tagSize: cappedTagSize).tags(
            for: dots.mapValues { EQTagLayout.Spot(x: $0.x, y: $0.y) }, width: size.width, height: size.height,
            pinned: grab?.pin)
        return Dictionary(
            uniqueKeysWithValues: dots.map { band, dot in
                let tag = tags[band]!
                return (band, EQBandPlace(dot: dot, tag: CGPoint(x: tag.x, y: tag.y)))
            })
    }

    /// The "L" point sits at the cutoff on the -3 dB line, where the filter starts to bite.
    private func lowCutPosition(in size: CGSize) -> CGPoint {
        let x = CGFloat(EQAxis.position(hertz: lowCutHertz ?? 100)) * size.width
        return CGPoint(x: x, y: EQGraphGrid.y(decibels: -3) * size.height)
    }

    private var lowCutHertz: Double? {
        guard let frequency = Catalog.lowCut(strip)?.frequency, let position = mirror.normalized(frequency) else {
            return nil
        }
        return frequency.scale.value(fromNormalized: position)
    }

    private func curve(_ bands: [EQBandState], _ lowCut: LowCutState?, in size: CGSize, upTo maxHertz: Double = 20_000)
        -> Path
    {
        var path = Path()
        let lastX = min(EQAxis.position(hertz: maxHertz), 1)
        for step in 0...120 {
            let x = Double(step) / 120 * lastX
            let hertz = EQAxis.hertz(at: x)
            let decibels = EQReading.decibels(at: hertz, bands: bands, lowCut: lowCut)
            let point = CGPoint(
                x: x * size.width, y: EQGraphGrid.y(decibels: decibels) * size.height)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isTouching) { _, touching, _ in touching = true }
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    grab = startGrab(at: value.startLocation, in: size)
                }
                guard let grab, value.translation != .zero else { return }
                move(grab, by: value.translation, in: size)
            }
            .onEnded { _ in endGrab() }
    }

    private func endGrab() {
        if let grab { pointAddresses(of: grab.band).forEach(mirror.endEdit) }
        isDragging = false
        grab = nil
    }

    /// nil when no point is near, or the band's values were never read: then the touch changes nothing.
    private func startGrab(at point: CGPoint, in size: CGSize) -> Grab? {
        let markers = markers(in: size)
        guard let band = nearestBand(to: point, among: markers), let origin = graphPosition(of: band) else { return nil }
        selectedBand = band
        pointAddresses(of: band).forEach(mirror.beginEdit)
        let place = markers[band]!
        return Grab(
            band: band, x: origin.x, y: origin.y, pin: EQTagLayout.Pin(band: band, offset: place.tag.x - place.dot.x))
    }

    /// Where a point is on the graph (0...1), from values the desk sent; nil if any was never read.
    private func graphPosition(of band: Int) -> (x: Float, y: Float)? {
        if band == Self.lowCutBand { return lowCutHertz.map { (Float(EQAxis.position(hertz: $0)), 0) } }
        let specs = Catalog.eqBand(strip, band)
        guard let frequency = mirror.normalized(specs.frequency), let gain = mirror.normalized(specs.gain) else {
            return nil
        }
        return (frequency, gain)
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .updating($isPinching) { _, pinching, _ in pinching = true }
            .onChanged { value in
                // The low cut, cut filters and shelves have no Q.
                guard selectedBand != Self.lowCutBand, mirror.eqBandHasQ(strip, selectedBand) == true else { return }
                let q = Catalog.eqBand(strip, selectedBand).q
                if pinchStartQ == nil {
                    guard let current = mirror.normalized(q) else { return }
                    pinchStartQ = current
                    mirror.beginEdit(q.address)
                }
                // Spreading the fingers widens the band; on the M32's Q scale, wider is a higher position.
                let next = (pinchStartQ ?? 0.5) + Float(log2(value.magnification)) * 0.25
                mirror.set(q, normalized: next)
            }
            .onEnded { _ in endPinch() }
    }

    private func endPinch() {
        if pinchStartQ != nil, selectedBand != Self.lowCutBand {
            mirror.endEdit(Catalog.eqBand(strip, selectedBand).q.address)
        }
        pinchStartQ = nil
    }

    /// Double-tap a band point to put that band back to its default, like double-tapping a row.
    private func resetGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2).onEnded { value in
            guard let band = nearestBand(to: value.location, among: markers(in: size)) else { return }
            selectedBand = band
            mirror.resetEQBand(strip, band)
        }
    }

    private func pointAddresses(of band: Int) -> [String] {
        if band == Self.lowCutBand { return Catalog.lowCut(strip).map { [$0.frequency.address] } ?? [] }
        let specs = Catalog.eqBand(strip, band)
        return [specs.frequency.address, specs.gain.address]
    }

    /// Only a touch near a dot or its tag grabs the band, so a stray touch on the graph changes nothing. On dots that
    /// share a spot the selected band wins, then the lower band (2026-10-22).
    private func nearestBand(to point: CGPoint, among markers: [Int: EQBandPlace]) -> Int? {
        let distances = points.map { band -> (Int, CGFloat) in
            let place = markers[band]!
            let distance = min(
                hypot(place.dot.x - point.x, place.dot.y - point.y), hypot(place.tag.x - point.x, place.tag.y - point.y))
            return (band, band == selectedBand ? distance - 0.5 : distance)
        }
        guard let nearest = distances.min(by: { $0.1 < $1.1 }), nearest.1 < 44 else { return nil }
        return nearest.0
    }

    private func move(_ grab: Grab, by translation: CGSize, in size: CGSize) {
        let x = grab.x + Float(translation.width / size.width)
        guard grab.band != Self.lowCutBand else { return moveLowCut(toGraphX: x) }
        let specs = Catalog.eqBand(strip, grab.band)
        mirror.set(specs.frequency, normalized: x)
        // Cut filters and the main-bus crossover types have no gain, so vertical movement is ignored.
        guard mirror.eqBandShapesLevel(strip, grab.band) == true else { return }
        let y = grab.y - Float(translation.height / size.height)
        mirror.set(specs.gain, normalized: y)
    }

    /// The low cut only moves sideways; its 20-400 Hz scale clamps a drag past either end.
    private func moveLowCut(toGraphX x: Float) {
        guard let frequency = Catalog.lowCut(strip)?.frequency else { return }
        let hertz = EQAxis.hertz(at: Double(x))
        mirror.set(frequency, value: hertz)
    }
}

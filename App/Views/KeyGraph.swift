import SwiftUI
import ThumbmixCore

/// What the gate or comp listens to (2026-10-20): the key filter over the RTA of the key's source, the glow bright
/// where the filter lets the sound through and dimmed where it cuts, and the live gain reduction along the bottom.
/// x follows the EQ graph's 20 Hz-20 kHz axis. The curve's y runs from 0 dB near the top to -30 dB at the bottom;
/// the glow keeps its own -90…0 dBFS scale, as on the EQ graph.
struct KeyGraph: View {
    let key: KeySpecs
    let strip: StripID
    let owner: KeyOwner
    let mirror: ConsoleMirror
    /// Freq during a drag (0...1), moved by the finger's travel like a row's value.
    @State private var dragPosition: Float?

    var body: some View {
        // Read here, not inside Canvas: Observation only tracks reads made during body.
        let filter = mirror.keyFilter(key)
        let isOn = mirror.isKeyFilterOn(key)
        let listened = mirror.keyRTA(strip, owner: owner)
        VStack(spacing: 8) {
            ZStack {
                Canvas { context, size in Self.drawGrid(in: context, size: size) }
                // Only once it's known what the key listens to: a guessed strip would caption the wrong glow.
                if let listened {
                    SpectrumGlow(
                        spectrum: mirror.spectrum, color: Theme.color(mirror.color(listened.strip)),
                        filter: isOn == true ? filter.map { shape in shape.decibels(at:) } : nil)
                }
                if let filter, let isOn { FilterCurve(filter: filter, isOn: isOn) }
                // Sideways only, like a row: a vertical swipe still scrolls or closes the sheet.
                HorizontalPanArea(
                    onBegan: beginDrag, onMoved: drag, onEnded: endDrag, onDoubleTap: {}, onHold: {},
                    onTouch: { $0 ? mirror.touchBegan() : mirror.touchEnded() })
            }
            .frame(height: Theme.graphHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("key-graph")
            .accessibilityLabel("Key filter")
            .accessibilityValue(Text(verbatim: spokenFilter(isOn: isOn)))
            .overlay(alignment: .bottom) {
                KeyReduction(meter: mirror.meter(strip), owner: owner, isOn: isDynamicsOn)
                    .padding(.horizontal, 12).padding(.bottom, 10)
                    .allowsHitTesting(false)
            }
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // A hold must not outlive the graph, or the desk's Freq would stay ignored.
            .onDisappear(perform: endDrag)
            RTAStatus(
                spectrum: mirror.spectrum, name: listened.map { mirror.name($0.strip) },
                afterEQ: listened?.afterEQ ?? true, isTakenByDesk: mirror.isRTATakenByDesk)
        }
        .modifier(BorrowsRTA(listened: listened, mirror: mirror))
    }

    /// Off reduces nothing, whatever the meter reports, as on the Gate and Comp graphs.
    private var isDynamicsOn: Bool {
        mirror.value(owner == .gate ? Catalog.gate(strip).on : Catalog.dynamics(strip).on) != 0
    }

    /// "LC12 150 Hz", and "Off" while the filter is off; nothing until read.
    private func spokenFilter(isOn: Bool?) -> String {
        let type = mirror.normalized(key.filterType)
        let frequency = mirror.normalized(key.filterFrequency)
        guard type != nil, frequency != nil else { return "" }
        let shape = ValueText.format(type, key.filterType) + " " + ValueText.format(frequency, key.filterFrequency)
        return isOn == false ? shape + ", " + FoldedLine.word(false) : shape
    }

    /// No drag while the filter is unread: the touch changes nothing, and no curve moves under a guess.
    private func beginDrag() {
        guard mirror.keyFilter(key) != nil, let current = mirror.normalized(key.filterFrequency) else { return }
        dragPosition = current
        mirror.beginEdit(key.filterFrequency.address)
    }

    private func drag(_ distance: CGFloat, _ width: CGFloat) {
        guard let position = dragPosition else { return }
        let moved = RelativeDrag.moved(position, by: Double(distance), width: Double(width))
        dragPosition = moved
        let new = key.filterFrequency.scale.snap(moved)
        guard new != mirror.normalized(key.filterFrequency) else { return }
        mirror.set(key.filterFrequency, normalized: new)
    }

    private func endDrag() {
        guard dragPosition != nil else { return }
        dragPosition = nil
        mirror.endEdit(key.filterFrequency.address)
    }

    static func y(decibels: Double, height: CGFloat) -> CGFloat {
        CGFloat(0.15 + 0.85 * min(max(-decibels / 30, 0), 1)) * height
    }

    private static func drawGrid(in context: GraphicsContext, size: CGSize) {
        var grid = Path()
        for decibels in [0.0, -12, -24] {
            let y = Self.y(decibels: decibels, height: size.height)
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        for hertz in [100.0, 1000, 10_000] {
            let x = EQAxis.position(hertz: hertz) * size.width
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        context.stroke(grid, with: .color(Theme.raised), lineWidth: 1)
    }
}

/// The filter's response and its point. Off, it stays drawn dashed and grey, like an EQ that's off (2026-10-14).
private struct FilterCurve: View {
    let filter: KeyFilterState
    let isOn: Bool
    @ScaledMetric private var pointSize: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Canvas { context, _ in
                context.stroke(
                    path(in: size), with: .color(isOn ? .white : Theme.secondaryText),
                    style: StrokeStyle(lineWidth: 2, dash: isOn ? [] : [5, 4]))
            }
            Circle()
                .fill(.white.opacity(isOn ? 1 : 0.5))
                .frame(width: pointSize, height: pointSize)
                .position(
                    x: EQAxis.position(hertz: filter.frequency) * size.width,
                    y: KeyGraph.y(decibels: filter.decibels(at: filter.frequency), height: size.height))
        }
        .allowsHitTesting(false)
    }

    private func path(in size: CGSize) -> Path {
        var path = Path()
        let steps = max(Int(size.width / 2), 1)
        for step in 0...steps {
            let x = Double(step) / Double(steps)
            let point = CGPoint(
                x: x * size.width, y: KeyGraph.y(decibels: filter.decibels(at: EQAxis.hertz(at: x)), height: size.height))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// Separate view so the 20 Hz meter updates redraw only the bar. A gate's cut is gain reduction too (doc p.17).
private struct KeyReduction: View {
    let meter: MeterCell
    let owner: KeyOwner
    let isOn: Bool

    var body: some View {
        ReductionBar(gain: isOn ? (owner == .gate ? meter.gateGain : meter.dynamicsGain) : 1)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("key-reduction")
    }
}

/// The desk's RTA is borrowed only while the graph is on screen and the app in front, like the EQ tab; a new key
/// source or comp position re-points it.
private struct BorrowsRTA: ViewModifier {
    let listened: KeyListening?
    let mirror: ConsoleMirror
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear(perform: follow)
            .onDisappear { mirror.releaseRTA() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { follow() } else { mirror.releaseRTA() }
            }
            .onChange(of: mirror.isLive) { _, isLive in if isLive, scenePhase == .active { follow() } }
            .onChange(of: listened) { follow() }
    }

    /// Not while the app is half hidden (Notification Center pulled down): a desk push mustn't borrow the RTA then.
    private func follow() {
        guard scenePhase == .active, let listened else { return }
        mirror.followRTA(listened.strip, afterEQ: listened.afterEQ)
    }
}

import SwiftUI
import ThumbmixCore

/// What the gate or comp listens to (2026-10-20): the key filter over the RTA of the key's source, the glow bright
/// where the filter lets the sound through and dimmed where it cuts, and the live gain reduction along the bottom.
/// x follows the EQ graph's 20 Hz-20 kHz axis; y runs from 0 dB near the top to -30 dB at the bottom.
struct KeyGraph: View {
    let key: KeySpecs
    let strip: StripID
    let owner: KeyOwner
    let mirror: ConsoleMirror
    /// Where Freq was at touch-down (0...1): a drag moves it by the finger's travel, like a row.
    @State private var dragStart: Float?
    /// Reset when a touch ends and when the system cancels it, which `onEnded` never reports.
    @GestureState private var isTouching = false

    var body: some View {
        // Read here, not inside Canvas: Observation only tracks reads made during body.
        let filter = mirror.keyFilter(key)
        let isOn = mirror.isKeyFilterOn(key)
        let listened = mirror.keyRTA(strip, owner: owner)
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack {
                    Canvas { context, size in Self.drawGrid(in: context, size: size) }
                    SpectrumGlow(
                        spectrum: mirror.spectrum, color: Theme.color(mirror.color(listened?.strip ?? strip)),
                        filter: isOn == true ? filter.map { shape in shape.decibels(at:) } : nil)
                    if let filter, let isOn { FilterCurve(filter: filter, isOn: isOn) }
                }
                .contentShape(Rectangle())
                .gesture(drag(width: geometry.size.width))
            }
            .frame(height: Theme.graphHeight)
            .overlay(alignment: .bottom) {
                KeyReduction(meter: mirror.meter(strip), owner: owner, isOn: isDynamicsOn)
                    .padding(.horizontal, 12).padding(.bottom, 10)
            }
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("key-graph")
            .accessibilityLabel("Key filter")
            .onChange(of: isTouching) { _, touching in if !touching { endDrag() } }
            RTAStatus(
                spectrum: mirror.spectrum, name: mirror.name(listened?.strip ?? strip),
                afterEQ: listened?.afterEQ ?? true)
        }
        .modifier(BorrowsRTA(listened: listened.map { Listened(strip: $0.strip, afterEQ: $0.afterEQ) }, mirror: mirror))
    }

    /// Off reduces nothing, whatever the meter reports, as on the Gate and Comp graphs.
    private var isDynamicsOn: Bool {
        mirror.value(owner == .gate ? Catalog.gate(strip).on : Catalog.dynamics(strip).on) != 0
    }

    /// No drag while the frequency is unread: the touch changes nothing.
    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isTouching) { _, touching, _ in touching = true }
            .onChanged { value in
                if dragStart == nil {
                    guard let start = mirror.normalized(key.filterFrequency) else { return }
                    dragStart = start
                    mirror.beginEdit(key.filterFrequency.address)
                }
                guard let dragStart, width > 0 else { return }
                mirror.set(key.filterFrequency, normalized: dragStart + Float(value.translation.width / width))
            }
            .onEnded { _ in endDrag() }
    }

    private func endDrag() {
        guard dragStart != nil else { return }
        mirror.endEdit(key.filterFrequency.address)
        dragStart = nil
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

private struct Listened: Equatable {
    let strip: StripID
    let afterEQ: Bool
}

/// The desk's RTA is borrowed only while the graph is on screen and the app in front, like the EQ tab; a new key
/// source or comp position re-points it.
private struct BorrowsRTA: ViewModifier {
    let listened: Listened?
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

    private func follow() {
        guard let listened else { return }
        mirror.followRTA(listened.strip, afterEQ: listened.afterEQ)
    }
}

import SwiftUI
import ThumbmixCore

struct GateTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// The other side of a pair whose dynamics aren't linked: its curve is drawn faint.
    var ghost: StripID?
    @State private var isKeyOpen = false

    var body: some View {
        let gate = Catalog.gate(strip)
        ScrollView {
            VStack(spacing: 8) {
                // Graph first, like the EQ tab (2026-10-15).
                TransferGraph(
                    curve: curve(gate), meter: mirror.meter(strip), reduction: \.gateGain,
                    identifier: "gate-graph", label: "Gate curve",
                    ghostOutput: ghost.flatMap { self.curve(Catalog.gate($0)) }?.output)
                HStack(spacing: 8) {
                    ToggleChip(spec: gate.on, mirror: mirror, onColor: .green)
                    ChoiceMenu(spec: gate.mode, mirror: mirror)
                }
                ForEach([gate.threshold, gate.range, gate.attack, gate.hold, gate.release]) {
                    ParameterRow(spec: $0, mirror: mirror)
                }
                // Set once: one line that opens a sheet, like the Comp's (2026-10-20).
                FoldedLineButton(line: mirror.gateKeyFold(strip), identifier: "gate-key") { isKeyOpen = true }
                // The shape only: On and the key are set once and stay, like Reset bands leaves EQ on.
                ResetButton(
                    title: "Reset gate", alertTitle: Text("Reset the gate of \(mirror.resetName(.gate, of: strip))?"),
                    isRead: mirror.isReadForReset(.gate, of: strip)
                ) {
                    mirror.resetGate(strip)
                }
            }
        }
        .sheet(isPresented: $isKeyOpen) {
            let title = mirror.sheetTitle(String(localized: "Gate key"), strip: strip, perSide: ghost != nil)
            FoldSheet(title: title, mirror: mirror) {
                KeySection(key: Catalog.gateKey(strip), strip: strip, owner: .gate, mirror: mirror)
            }
            .foldSheetPresentation([.large])
        }
    }

    /// nil until the desk has sent every value the curve needs: the graph never draws a guess.
    private func curve(_ gate: GateSpecs) -> TransferGraph.Curve? {
        guard let modeIndex = mirror.value(gate.mode), let mode = TransferCurve.GateMode(rawValue: Int(modeIndex)),
            let threshold = mirror.value(gate.threshold), let range = mirror.value(gate.range),
            let on = mirror.value(gate.on)
        else { return nil }
        return TransferGraph.Curve(
            output: { TransferCurve.gateOutput($0, mode: mode, threshold: threshold, range: range) },
            threshold: threshold, isOn: on == 1)
    }
}

struct CompTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// The other side of a pair whose dynamics aren't linked: its curve is drawn faint.
    var ghost: StripID?
    @State private var isMoreOpen = false

    var body: some View {
        let dynamics = Catalog.dynamics(strip)
        ScrollView {
            VStack(spacing: 8) {
                // Graph first, like the EQ tab (2026-10-15).
                TransferGraph(
                    curve: curve(dynamics), meter: mirror.meter(strip), reduction: \.dynamicsGain,
                    identifier: "comp-graph", label: "Compressor curve",
                    ghostOutput: ghost.flatMap { self.curve(Catalog.dynamics($0)) }?.output)
                // Auto last (U1, 2026-10-20): a tap that misses it opens Mode, never switches the comp off.
                HStack(spacing: 8) {
                    ToggleChip(spec: dynamics.on, mirror: mirror, onColor: .green)
                    ChoiceMenu(spec: dynamics.mode, mirror: mirror)
                    ToggleChip(spec: dynamics.auto, mirror: mirror, title: String(localized: "Auto"), onColor: .green)
                }
                // Auto time takes over Attack and Release: dimmed in place, like a cut filter's Gain and Q.
                let autoTimed = mirror.isAutoTimeOn(strip) ? Set(dynamics.autoTimed.map(\.address)) : []
                // What's ridden mid-show first, in reach on the SE without a scroll (mock B, 2026-10-20).
                ForEach([
                    dynamics.threshold, dynamics.ratio, dynamics.makeup, dynamics.mix, dynamics.knee, dynamics.attack,
                    dynamics.hold, dynamics.release,
                ]) {
                    ParameterRow(spec: $0, mirror: mirror).disabled(autoTimed.contains($0.address))
                }
                // What nobody rides is one line that opens a sheet: the tab never changes length.
                FoldedLineButton(line: mirror.compFold(strip), identifier: "comp-more") { isMoreOpen = true }
                // The shape only: On, the key and Comp position stay.
                ResetButton(
                    title: "Reset comp", alertTitle: Text("Reset the comp of \(mirror.resetName(.comp, of: strip))?"),
                    isRead: mirror.isReadForReset(.comp, of: strip)
                ) {
                    mirror.resetDynamics(strip)
                }
            }
        }
        .sheet(isPresented: $isMoreOpen) {
            FoldSheet(title: mirror.sheetTitle(String(localized: "Comp"), strip: strip, perSide: ghost != nil), mirror: mirror) {
                CompMoreSettings(strip: strip, mirror: mirror)
            }
            .foldSheetPresentation([.large])
        }
    }

    /// nil until the desk has sent every value the curve needs: the graph never draws a guess.
    private func curve(_ dynamics: DynamicsSpecs) -> TransferGraph.Curve? {
        guard let mode = mirror.value(dynamics.mode), let threshold = mirror.value(dynamics.threshold),
            let ratioIndex = mirror.value(dynamics.ratio), let ratio = Double(Catalog.ratios[Int(ratioIndex)]),
            let knee = mirror.value(dynamics.knee), let makeup = mirror.value(dynamics.makeup),
            let mix = mirror.value(dynamics.mix), let on = mirror.value(dynamics.on)
        else { return nil }
        let isExpander = mode == 1
        let output = { (input: Double) in
            TransferCurve.dynamicsOutput(
                input, isExpander: isExpander, threshold: threshold, ratio: ratio, knee: knee, makeup: makeup,
                mix: mix)
        }
        return TransferGraph.Curve(output: output, threshold: threshold, isOn: on == 1)
    }
}

/// The Comp's sheet (mock B, 2026-10-20): the key first, then the detector and where the comp sits.
private struct CompMoreSettings: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        let dynamics = Catalog.dynamics(strip)
        KeySection(key: Catalog.dynamicsKey(strip), strip: strip, owner: .comp, mirror: mirror)
        Text("Detector").sectionLabel()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.top, 10)
        HStack(spacing: 8) {
            ChoiceMenu(spec: dynamics.detector, mirror: mirror)
            ChoiceMenu(spec: dynamics.envelope, mirror: mirror)
        }
        if let position = Catalog.dynamicsPosition(strip) {
            CompPositionMenu(spec: position, strip: strip, mirror: mirror)
        }
    }
}

/// What the gate or comp listens to: opened from the tab's folded line, never on the tab itself.
struct KeySection: View {
    let key: KeySpecs
    /// The gate's or comp's own strip: the side shown, for a pair whose dynamics aren't linked.
    let strip: StripID
    let owner: KeyOwner
    let mirror: ConsoleMirror

    var body: some View {
        // Source in the heading (S2, 2026-10-20): set once, it needn't cost a row.
        HStack {
            Text("Key").sectionLabel()
            Spacer(minLength: 8)
            if let source = key.sourceAddress {
                ChoiceMenu(
                    spec: Catalog.keySource(source, rawName: mirror.rawName), mirror: mirror,
                    compactLabel: String(localized: "Listens to"))
            }
        }
        .padding(.horizontal, 4)
        KeyGraph(key: key, strip: strip, owner: owner, mirror: mirror)
        HStack(spacing: 8) {
            ToggleChip(spec: key.filterOn, mirror: mirror, onColor: .green)
            ChoiceMenu(spec: key.filterType, mirror: mirror)
        }
        // Stays live with the filter off, like Delay's time: set the frequency, then switch it on.
        ParameterRow(spec: key.filterFrequency, mirror: mirror)
    }
}

/// Moving the comp across the EQ changes what sends tapped around the EQ hear, so it names those mixes and asks
/// first (mock b1, 2026-10-14). Disabled until every tap is read: unknown mustn't pass for "no mix changes".
struct CompPositionMenu: View {
    let spec: ParamSpec
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var pending: OSCArgument?

    var body: some View {
        let mixes = mirror.mixesChangedByMovingComp(of: strip)
        ChoiceMenu(spec: spec, mirror: mirror) { argument in
            guard argument != mirror.cell(spec.address).argument else { return }
            if mixes?.isEmpty == false { pending = argument } else { mirror.set(spec.address, argument) }
        }
        .disabled(mixes == nil)
        .alert(prompt.title, isPresented: isAsking, presenting: pending) { argument in
            Button("Move") { mirror.set(spec.address, argument) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text(prompt.message)
        }
    }

    private var prompt: CompMovePrompt {
        CompMovePrompt(movesBeforeEQ: pending == .int(0), mixes: mirror.mixesChangedByMovingComp(of: strip) ?? [])
    }

    private var isAsking: Binding<Bool> {
        Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
    }
}

#if DEBUG
    #Preview("Gate") {
        GateTab(strip: StripID(.input, 1), mirror: .preview()).padding().background(Theme.background)
    }

    #Preview("Comp") {
        CompTab(strip: StripID(.input, 1), mirror: .preview()).padding().background(Theme.background)
    }
#endif

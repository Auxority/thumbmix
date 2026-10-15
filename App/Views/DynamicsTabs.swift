import SwiftUI
import ThumbmixCore

struct GateTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// The other side of a pair whose dynamics aren't linked: its curve is drawn faint.
    var ghost: StripID?

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
                KeySection(key: Catalog.gateKey(strip), mirror: mirror)
            }
        }
    }

    /// nil until the desk has sent every value the curve needs: the graph never draws a guess.
    private func curve(_ gate: GateSpecs) -> TransferGraph.Curve? {
        guard let modeIndex = mirror.value(gate.mode), let mode = TransferCurve.GateMode(rawValue: Int(modeIndex)),
            let threshold = mirror.value(gate.threshold), let range = mirror.value(gate.range)
        else { return nil }
        return TransferGraph.Curve(
            output: { TransferCurve.gateOutput($0, mode: mode, threshold: threshold, range: range) },
            threshold: threshold)
    }
}

struct CompTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// The other side of a pair whose dynamics aren't linked: its curve is drawn faint.
    var ghost: StripID?

    var body: some View {
        let dynamics = Catalog.dynamics(strip)
        ScrollView {
            VStack(spacing: 8) {
                // Graph first, like the EQ tab (2026-10-15).
                TransferGraph(
                    curve: curve(dynamics), meter: mirror.meter(strip), reduction: \.dynamicsGain,
                    identifier: "comp-graph", label: "Compressor curve",
                    ghostOutput: ghost.flatMap { self.curve(Catalog.dynamics($0)) }?.output)
                HStack(spacing: 8) {
                    ToggleChip(spec: dynamics.on, mirror: mirror, onColor: .green)
                    ChoiceMenu(spec: dynamics.mode, mirror: mirror)
                }
                // Auto time takes over Attack and Release: dimmed in place, like a cut filter's Gain and Q.
                let autoTimed = mirror.isAutoTimeOn(strip) ? Set(dynamics.autoTimed.map(\.address)) : []
                ForEach([
                    dynamics.threshold, dynamics.ratio, dynamics.knee, dynamics.attack, dynamics.hold,
                    dynamics.release, dynamics.makeup,
                ]) {
                    ParameterRow(spec: $0, mirror: mirror).disabled(autoTimed.contains($0.address))
                }
                // Set and forget: below the settings an engineer rides.
                HStack(spacing: 8) {
                    ChoiceMenu(spec: dynamics.detector, mirror: mirror)
                    ChoiceMenu(spec: dynamics.envelope, mirror: mirror)
                }
                HStack(spacing: 8) {
                    if let position = Catalog.dynamicsPosition(strip) {
                        CompPositionMenu(spec: position, strip: strip, mirror: mirror)
                    }
                    ToggleChip(spec: dynamics.auto, mirror: mirror, onColor: .green)
                }
                KeySection(key: Catalog.dynamicsKey(strip), mirror: mirror)
            }
        }
    }

    /// nil until the desk has sent every value the curve needs: the graph never draws a guess.
    private func curve(_ dynamics: DynamicsSpecs) -> TransferGraph.Curve? {
        guard let mode = mirror.value(dynamics.mode), let threshold = mirror.value(dynamics.threshold),
            let ratioIndex = mirror.value(dynamics.ratio), let ratio = Double(Catalog.ratios[Int(ratioIndex)]),
            let knee = mirror.value(dynamics.knee), let makeup = mirror.value(dynamics.makeup)
        else { return nil }
        let isExpander = mode == 1
        let output = { (input: Double) in
            TransferCurve.dynamicsOutput(
                input, isExpander: isExpander, threshold: threshold, ratio: ratio, knee: knee, makeup: makeup)
        }
        return TransferGraph.Curve(output: output, threshold: threshold)
    }
}

/// What the gate or comp listens to (layout A, 2026-10-14): last, below everything an engineer rides.
struct KeySection: View {
    let key: KeySpecs
    let mirror: ConsoleMirror

    var body: some View {
        Text("Key")
            .font(.footnote).textCase(.uppercase).foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.top, 10)
        if let source = key.sourceAddress {
            ChoiceMenu(spec: Catalog.keySource(source, rawName: mirror.rawName), mirror: mirror)
        }
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

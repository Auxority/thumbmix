import SwiftUI
import ThumbmixCore

struct GateTab: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        let gate = Catalog.gate(strip)
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ToggleChip(spec: gate.on, mirror: mirror, onColor: .green)
                    ParameterRow(spec: gate.mode, mirror: mirror)
                }
                if let curve = curve(gate) {
                    TransferGraph(
                        output: curve.output, threshold: curve.threshold, meter: mirror.meter(strip),
                        reduction: \.gateGain, identifier: "gate-graph", label: "Gate curve")
                }
                ForEach([gate.threshold, gate.range, gate.attack, gate.hold, gate.release]) {
                    ParameterRow(spec: $0, mirror: mirror)
                }
            }
        }
    }

    /// nil until the desk has sent every value the curve needs: the graph never draws a guess.
    private func curve(_ gate: GateSpecs) -> (output: (Double) -> Double, threshold: Double)? {
        guard let modeIndex = mirror.value(gate.mode), let mode = TransferCurve.GateMode(rawValue: Int(modeIndex)),
            let threshold = mirror.value(gate.threshold), let range = mirror.value(gate.range)
        else { return nil }
        return ({ TransferCurve.gateOutput($0, mode: mode, threshold: threshold, range: range) }, threshold)
    }
}

struct CompTab: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        let dynamics = Catalog.dynamics(strip)
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ToggleChip(spec: dynamics.on, mirror: mirror, onColor: .green)
                    ParameterRow(spec: dynamics.mode, mirror: mirror)
                }
                if let curve = curve(dynamics) {
                    TransferGraph(
                        output: curve.output, threshold: curve.threshold, meter: mirror.meter(strip),
                        reduction: \.dynamicsGain, identifier: "comp-graph", label: "Compressor curve")
                }
                ForEach([
                    dynamics.threshold, dynamics.ratio, dynamics.knee, dynamics.attack, dynamics.hold,
                    dynamics.release, dynamics.makeup,
                ]) {
                    ParameterRow(spec: $0, mirror: mirror)
                }
            }
        }
    }

    /// nil until the desk has sent every value the curve needs: the graph never draws a guess.
    private func curve(_ dynamics: DynamicsSpecs) -> (output: (Double) -> Double, threshold: Double)? {
        guard let mode = mirror.value(dynamics.mode), let threshold = mirror.value(dynamics.threshold),
            let ratioIndex = mirror.value(dynamics.ratio), let ratio = Double(Catalog.ratios[Int(ratioIndex)]),
            let knee = mirror.value(dynamics.knee), let makeup = mirror.value(dynamics.makeup)
        else { return nil }
        let isExpander = mode == 1
        let output = { (input: Double) in
            TransferCurve.dynamicsOutput(
                input, isExpander: isExpander, threshold: threshold, ratio: ratio, knee: knee, makeup: makeup)
        }
        return (output, threshold)
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

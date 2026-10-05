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
                DynamicsMeter(cell: mirror.meter(strip), threshold: decibels(gate.threshold), reduction: \.gateGain)
                ForEach([gate.threshold, gate.range, gate.attack, gate.hold, gate.release]) {
                    ParameterRow(spec: $0, mirror: mirror)
                }
            }
        }
    }

    private func decibels(_ spec: ParamSpec) -> Double? {
        mirror.normalized(spec).map(spec.scale.value(fromNormalized:))
    }
}

struct CompTab: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        let dynamics = Catalog.dynamics(strip)
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    ToggleChip(spec: dynamics.on, mirror: mirror, onColor: .green)
                    Spacer()
                }
                DynamicsMeter(cell: mirror.meter(strip), threshold: decibels(dynamics.threshold), reduction: \.dynamicsGain)
                ForEach([dynamics.threshold, dynamics.ratio, dynamics.knee, dynamics.attack, dynamics.hold, dynamics.release, dynamics.makeup]) {
                    ParameterRow(spec: $0, mirror: mirror)
                }
            }
        }
    }

    private func decibels(_ spec: ParamSpec) -> Double? {
        mirror.normalized(spec).map(spec.scale.value(fromNormalized:))
    }
}

/// Input level with the threshold marked, plus gain reduction. Reads the meter cell itself so
/// 20 Hz updates don't redraw the parameter rows.
private struct DynamicsMeter: View {
    let cell: MeterCell
    let threshold: Double?
    let reduction: KeyPath<MeterCell, Float>

    var body: some View {
        VStack(spacing: 8) {
            MeterBar(level: cell.level, threshold: threshold, height: 12)
            ReductionBar(gain: cell[keyPath: reduction])
        }
        .padding(12)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
    }
}

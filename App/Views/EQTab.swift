import SwiftUI
import ThumbmixCore

struct EQTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var band = 1
    @State private var isConfirmingReset = false

    var body: some View {
        let lowCut = Catalog.lowCut(strip)
        // One scroll view for the whole tab: a fixed graph left the rows a sliver of their own to scroll in.
        ScrollView {
            VStack(spacing: 8) {
                EQGraph(strip: strip, mirror: mirror, selectedBand: $band)
                    .frame(height: 190)
                HStack(spacing: 8) {
                    ToggleChip(spec: Catalog.eqOn(strip), mirror: mirror, onColor: .green)
                    Picker("Band", selection: $band) {
                        if lowCut != nil { Text("LC").tag(EQGraph.lowCutBand) }
                        ForEach(1...strip.eqBandCount, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                // The low cut shares the band rows' space: picking it swaps the rows, never adds any.
                if band == EQGraph.lowCutBand, let lowCut {
                    lowCutRows(lowCut)
                } else {
                    bandRows(Catalog.eqBand(strip, band))
                }
                if let defaults = Catalog.eqDefaults(strip) { resetButton(bandCount: defaults.count) }
            }
        }
    }

    @ViewBuilder private func bandRows(_ specs: EQBandSpecs) -> some View {
        ChoiceMenu(spec: specs.type, mirror: mirror)
        ForEach([specs.frequency, specs.gain, specs.q]) { ParameterRow(spec: $0, mirror: mirror) }
    }

    /// On the desk the low cut belongs to the preamp, so "Reset bands" leaves it alone.
    @ViewBuilder private func lowCutRows(_ lowCut: LowCutSpecs) -> some View {
        HStack(spacing: 8) {
            ToggleChip(spec: lowCut.on, mirror: mirror, onColor: EQGraph.lowCutColor)
            ParameterRow(spec: lowCut.frequency, mirror: mirror, accent: EQGraph.lowCutColor)
        }
        ChoiceMenu(spec: lowCut.slope, mirror: mirror)
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

#if DEBUG
    #Preview {
        EQTab(strip: StripID(.input, 1), mirror: .preview()).padding().background(Theme.background)
    }
#endif

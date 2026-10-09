import SwiftUI
import ThumbmixCore

struct EQTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// The other side of a pair whose EQ isn't linked: its curve is drawn faint.
    var ghost: StripID?
    @State private var band = 1
    @State private var isConfirmingReset = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let lowCut = Catalog.lowCut(strip)
        // One scroll view for the whole tab: a fixed graph left the rows a sliver of their own to scroll in.
        ScrollView {
            VStack(spacing: 8) {
                EQGraph(strip: strip, mirror: mirror, selectedBand: $band, ghost: ghost)
                    .frame(height: 190)
                RTAStatus(spectrum: mirror.spectrum, name: mirror.name(strip))
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
        // The desk's RTA is borrowed only while this tab is on screen, and handed back when the app leaves the foreground.
        .onAppear { mirror.followRTA(strip) }
        .onDisappear { mirror.releaseRTA() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { mirror.followRTA(strip) } else { mirror.releaseRTA() }
        }
        // Coming back from the background rebuilds the link, so the borrow above finds it not live yet: retry once it is.
        .onChange(of: mirror.isLive) { _, isLive in
            if isLive, scenePhase == .active { mirror.followRTA(strip) }
        }
    }

    /// A cut filter's Gain and Q do nothing, so they're disabled, not removed: nothing below them moves.
    @ViewBuilder private func bandRows(_ specs: EQBandSpecs) -> some View {
        let shapesLevel = mirror.eqBandShapesLevel(strip, band) != false
        ChoiceMenu(spec: specs.type, mirror: mirror)
        ParameterRow(spec: specs.frequency, mirror: mirror)
        ForEach([specs.gain, specs.q]) { ParameterRow(spec: $0, mirror: mirror).disabled(!shapesLevel) }
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
            .alert("Reset all \(bandCount) bands of \(mirror.name(strip))?", isPresented: $isConfirmingReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { mirror.resetEQBands(strip) }
            }
    }
}

#if DEBUG
    #Preview {
        EQTab(strip: StripID(.input, 1), mirror: .preview()).padding().background(Theme.background)
    }
#endif

import SwiftUI
import ThumbmixCore

struct EQTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// The other side of a pair whose EQ isn't linked: its curve is drawn faint.
    var ghost: StripID?
    @State private var band = 1
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let lowCut = Catalog.lowCut(strip)
        // One scroll view for the whole tab: a fixed graph left the rows a sliver of their own to scroll in.
        ScrollView {
            VStack(spacing: 8) {
                EQGraph(strip: strip, mirror: mirror, selectedBand: $band, ghost: ghost)
                    .frame(height: Theme.graphHeight)
                RTAStatus(spectrum: mirror.spectrum, name: mirror.name(strip), isTakenByDesk: mirror.isRTATakenByDesk)
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
                if let defaults = Catalog.eqDefaults(strip) {
                    ResetButton(
                        title: "Reset bands", alertTitle: Text("Reset all \(defaults.count) bands of \(mirror.resetName(.eq, of: strip))?"),
                        isRead: mirror.isReadForReset(.eq, of: strip)
                    ) { mirror.resetEQBands(strip) }
                }
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
        // Picking L or R of an unlinked pair swaps the strip but keeps this view, so onAppear doesn't run again.
        .onChange(of: strip) { mirror.followRTA(strip) }
    }

    /// A cut filter's Gain and Q do nothing, and a shelf shows no Q on the desk, so they're disabled, not removed:
    /// nothing below them moves.
    @ViewBuilder private func bandRows(_ specs: EQBandSpecs) -> some View {
        ChoiceMenu(spec: specs.type, mirror: mirror)
        ParameterRow(spec: specs.frequency, mirror: mirror)
        ParameterRow(spec: specs.gain, mirror: mirror).disabled(mirror.eqBandShapesLevel(strip, band) == false)
        ParameterRow(spec: specs.q, mirror: mirror).disabled(mirror.eqBandHasQ(strip, band) == false)
    }

    /// On the desk the low cut belongs to the preamp, so "Reset bands" leaves it alone.
    @ViewBuilder private func lowCutRows(_ lowCut: LowCutSpecs) -> some View {
        HStack(spacing: 8) {
            ToggleChip(spec: lowCut.on, mirror: mirror, onColor: EQGraph.lowCutColor)
            ParameterRow(spec: lowCut.frequency, mirror: mirror, accent: EQGraph.lowCutColor)
        }
    }
}

#if DEBUG
    #Preview {
        EQTab(strip: StripID(.input, 1), mirror: .preview()).padding().background(Theme.background)
    }
#endif

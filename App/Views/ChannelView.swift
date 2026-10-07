import SwiftUI
import ThumbmixCore

/// A strip's screen. A linked pair opens here as one stereo strip held by its odd side: each tab shows once while
/// the desk links its section, and one side at a time (L | R) when it doesn't.
struct ChannelView: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var tab = ChannelTab.mix
    @State private var showsRight = false

    var body: some View {
        let tabs = ChannelTab.tabs(for: strip.kind)
        let unlinked = mirror.unlinkedSection(of: tab, for: main)
        VStack(spacing: 12) {
            ChannelHeader(strip: main, mirror: mirror)
            if tab != .mix { SlimMixRow(strip: slimStrip, mirror: mirror) }
            if unlinked != nil { PairSidePicker(odd: main, tab: tab, mirror: mirror, showsRight: $showsRight) }
            ChannelTabContent(
                tab: tab, strip: unlinked == nil ? main : side, mirror: mirror,
                ghost: unlinked == nil ? nil : side.partner, panPartner: mixPanPartner)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .disabled(!mirror.isLive)
        .opacity(mirror.isLive ? 1 : 0.4)
        .background(Theme.background)
        .safeAreaInset(edge: .top, spacing: 0) { StatusBanner(status: mirror.status) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if tabs.count > 1 { StripTabBar(tabs: tabs, selection: $tab) }
        }
        .onChange(of: tab) { showsRight = false }
        .navigationTitle(title)
        .demoTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isPair: Bool { mirror.isLinked(strip) }

    /// The strip the screen works from: a pair's odd side, whichever side it was opened or linked from.
    private var main: StripID { isPair ? strip.oddSide : strip }

    private var side: StripID { showsRight ? (main.partner ?? main) : main }

    private var title: String { isPair ? strip.pairDefaultName : strip.defaultName }

    /// The slim fader above the other tabs follows the chosen side only when the desk doesn't link faders.
    private var slimStrip: StripID { mirror.unlinkedSection(of: .mix, for: main) == nil ? main : side }

    /// One fader drives both sides, but the desk keeps a pan per side: the Mix tab shows both.
    private var mixPanPartner: StripID? {
        isPair && mirror.unlinkedSection(of: .mix, for: main) == nil ? main.partner : nil
    }
}

/// The tab's own view for `strip`; `ghost` is the other side of a pair whose sides can differ, drawn faint in graphs.
private struct ChannelTabContent: View {
    let tab: ChannelTab
    let strip: StripID
    let mirror: ConsoleMirror
    let ghost: StripID?
    let panPartner: StripID?

    var body: some View {
        switch tab {
        case .mix: MixTab(strip: strip, mirror: mirror, panPartner: panPartner)
        case .input: InputTab(strip: strip, mirror: mirror)
        case .members: MembersTab(dca: strip.number, mirror: mirror)
        case .gate: GateTab(strip: strip, mirror: mirror, ghost: ghost)
        case .comp: CompTab(strip: strip, mirror: mirror, ghost: ghost)
        case .eq: EQTab(strip: strip, mirror: mirror, ghost: ghost)
        case .sends: SendsTab(strip: strip, mirror: mirror)
        case .fedBy: FedByTab(bus: strip, mirror: mirror)
        }
    }
}

#if DEBUG
    #Preview("Input") {
        NavigationStack { ChannelView(strip: StripID(.input, 13), mirror: .preview()) }
    }

    #Preview("Pair") {
        NavigationStack { ChannelView(strip: StripID(.input, 9), mirror: .preview()) }
    }

    #Preview("Bus") {
        NavigationStack { ChannelView(strip: StripID(.bus, 1), mirror: .preview()) }
    }

    #Preview("DCA") {
        NavigationStack { ChannelView(strip: StripID(.dca, 1), mirror: .preview()) }
    }
#endif

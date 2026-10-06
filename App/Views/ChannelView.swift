import SwiftUI
import ThumbmixCore

struct ChannelView: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var tab = ChannelTab.mix

    var body: some View {
        let tabs = ChannelTab.tabs(for: strip.kind)
        VStack(spacing: 12) {
            ChannelHeader(strip: strip, mirror: mirror)
            if tab != .mix { SlimMixRow(strip: strip, mirror: mirror) }
            content
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
        .navigationTitle(strip.defaultName)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .mix: MixTab(strip: strip, mirror: mirror)
        case .input: InputTab(strip: strip, mirror: mirror)
        case .members: MembersTab(dca: strip.number, mirror: mirror)
        case .gate: GateTab(strip: strip, mirror: mirror)
        case .comp: CompTab(strip: strip, mirror: mirror)
        case .eq: EQTab(strip: strip, mirror: mirror)
        case .sends: SendsTab(strip: strip, mirror: mirror)
        case .fedBy: FedByTab(bus: strip, mirror: mirror)
        }
    }
}

#if DEBUG
    #Preview("Input") {
        NavigationStack { ChannelView(strip: StripID(.input, 13), mirror: .preview()) }
    }

    #Preview("Bus") {
        NavigationStack { ChannelView(strip: StripID(.bus, 1), mirror: .preview()) }
    }

    #Preview("DCA") {
        NavigationStack { ChannelView(strip: StripID(.dca, 1), mirror: .preview()) }
    }
#endif

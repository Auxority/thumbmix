import SwiftUI
import ThumbmixCore

struct ChannelView: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var tab: ChannelTab

    init(strip: StripID, mirror: ConsoleMirror) {
        self.strip = strip
        self.mirror = mirror
        _tab = State(initialValue: ChannelTab.tabs(for: strip.kind).first ?? .input)
    }

    var body: some View {
        let tabs = ChannelTab.tabs(for: strip.kind)
        VStack(spacing: 12) {
            ChannelHeader(strip: strip, mirror: mirror)
            if !tabs.isEmpty {
                Picker("Section", selection: $tab) {
                    ForEach(tabs) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            content
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .disabled(!mirror.isLive)
        .opacity(mirror.isLive ? 1 : 0.4)
        .background(Theme.background)
        .safeAreaInset(edge: .top, spacing: 0) { StatusBanner(status: mirror.status) }
        .navigationTitle(strip.defaultName)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .input: InputTab(strip: strip, mirror: mirror)
        case .members: MembersTab(dca: strip.number, mirror: mirror)
        case .gate: GateTab(strip: strip, mirror: mirror)
        case .comp: CompTab(strip: strip, mirror: mirror)
        default: EmptyView()
        }
    }
}

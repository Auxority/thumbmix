import SwiftUI
import ThumbmixCore
import TipKit

struct OverviewView: View {
    let mirror: ConsoleMirror
    let onDisconnect: () -> Void
    /// The engineer kept the desk's Exclusive solo: the app remembers it per desk.
    var onKeepExclusive: () -> Void = {}
    @State private var group: StripGroup = .inputs
    @State private var openStrip: StripID?
    /// The mute group a hold on the Main page opened.
    @State private var openMuteGroup: Int?
    /// One open fold for every group of the overview.
    @AppStorage(UnusedFoldRow.overviewKey) private var showsUnused = false
    @State private var stroke = SoloStrokeDriver()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ScrollViewReader { proxy in
                    ScrollView {
                        let list = mirror.overviewList(group.strips, showUnused: showsUnused)
                        let unused = list.unused
                        SteadyRows(wanted: list.items, mirror: mirror) {
                            rows in
                            LazyVStack(spacing: 6) {
                                ForEach(rows) { item in
                                    row(item, of: rows, proxy: proxy).opacity(unused.contains(item.held) ? 0.45 : 1)
                                }
                                if !unused.isEmpty { UnusedFoldRow(strips: unused, isOpen: $showsUnused) }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                    .coordinateSpace(SoloStrokeDriver.space)
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        stroke.viewportHeight = $0
                    }
                    .onGeometryChange(for: CGFloat.self) {
                        $0.safeAreaInsets.bottom
                    } action: {
                        stroke.bottomInset = $0
                    }
                }
                .sensoryFeedback(.selection, trigger: stroke.ticks)
                .keepsFoldInPlace()
                // Each list gets its own scroll view, so it starts where a list naturally starts. Keeping
                // one left the old offset past a shorter list (only black), and scrolling it to a top
                // anchor shifted the rows on iOS 27. A reconnect keeps the position: no list moves under a finger.
                .id(group)
                .disabled(!mirror.isLive)
                .opacity(mirror.isLive ? 1 : 0.4)
            }
            // In thumb reach; the list scrolls on under the glass, and its last row scrolls clear of it. Kept off the
            // list's `.id(group)`, so switching groups doesn't rebuild the bar under the finger.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    // Grows the inset below the list, so the rows on screen stay where they are. The tip sits here, not
                    // as a popover on a name: a popover takes the first touch, so the engineer's first hold did nothing.
                    if mirror.soloedCount > 0 {
                        SoloBar(mirror: mirror)
                    } else {
                        TipView(SoloStrokeTip()).padding(.horizontal, 12)
                    }
                    if group == .main { muteGroups }
                    PillBar(items: StripGroup.allCases, selection: $group, title: \.shortTitle, label: \.title)
                }
            }
            .background(Theme.background)
            .soloStrokeLifecycle(stroke, mirror: mirror, onKeep: onKeepExclusive)
            .safeAreaInset(edge: .top, spacing: 0) { StatusBanner(mirror: mirror) }
            // No title (2026-10-15): the bar holds Disconnect, and in Offline mode the DEMO pill, nothing more.
            .demoTitle(nil)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Disconnect", action: onDisconnect).buttonStyle(.darkCapsule)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .navigationDestination(item: $openStrip) { strip in
                ChannelView(strip: strip, mirror: mirror)
            }
            .navigationDestination(item: $openMuteGroup) { group in
                MuteGroupMembersView(group: group, mirror: mirror)
            }
        }
    }

    /// Pinned above the pills, so all six stay in reach (I3, 2026-10-19). Read again each time the page opens: whether
    /// the desk pushes a group switched on it is unverified (m32-probe section 14).
    private var muteGroups: some View {
        VStack(spacing: 6) {
            TipView(MuteGroupHoldTip())
            MuteGroupGrid(mirror: mirror) { group in
                openMuteGroup = group
                Task { await MuteGroupHoldTip.openedByHolding.donate() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .disabled(!mirror.isLive)
        .onAppear { mirror.readMuteGroups() }
    }

    private func row(_ item: OverviewItem, of rows: [OverviewItem], proxy: ScrollViewProxy) -> some View {
        StripRow(
            item: item, mirror: mirror, onOpen: { openStrip = item.opens },
            onSoloHold: { phase, point in
                stroke.hold(phase, at: point, on: item, rows: rows, mirror: mirror, proxy: proxy)
            },
            isHeld: stroke.held == item
        )
        .id(item)
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: SoloStrokeDriver.space)
        } action: {
            stroke.frames[item] = $0
        }
    }
}

#if DEBUG
    #Preview {
        OverviewView(mirror: .preview(), onDisconnect: {})
    }
#endif

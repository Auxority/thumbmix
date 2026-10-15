import SwiftUI
import ThumbmixCore

struct OverviewView: View {
    let mirror: ConsoleMirror
    let onDisconnect: () -> Void
    @State private var group: StripGroup = .inputs
    @State private var openStrip: StripID?
    /// One open fold for every group of the overview.
    @AppStorage(UnusedFoldRow.overviewKey) private var showsUnused = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ScrollView {
                    let unused = mirror.unusedStrips(group.strips, where: mirror.isUnused)
                    SteadyRows(wanted: mirror.overviewItems(group.strips, showUnused: showsUnused), mirror: mirror) { rows in
                        LazyVStack(spacing: 6) {
                            ForEach(rows) { item in
                                StripRow(item: item, mirror: mirror) { openStrip = item.opens }
                                    .opacity(unused.contains(item.held) ? 0.45 : 1)
                            }
                            if !unused.isEmpty { UnusedFoldRow(strips: unused, isOpen: $showsUnused) }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .keepsFoldInPlace()
                // Each list gets its own scroll view, so it starts where a list naturally starts. Keeping
                // one left the old offset past a shorter list (only black), and scrolling it to a top
                // anchor shifted the rows on iOS 27. A reconnect keeps the position: no list moves under a finger.
                .id(group)
                .disabled(!mirror.isLive)
                .opacity(mirror.isLive ? 1 : 0.4)
            }
            // In thumb reach; the list scrolls on under the glass, and its last row scrolls clear of it. Kept off the
            // list's `.id(group)`: a new list rebuilt the chips too, jumping their bar back to Inputs.
            .safeAreaInset(edge: .bottom, spacing: 0) { GroupChips(selection: $group) }
            .background(Theme.background)
            .safeAreaInset(edge: .top, spacing: 0) { StatusBanner(status: mirror.status) }
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
        }
    }
}

/// One dark glass bar of chips (mock A2): it scrolls sideways, so a new group is just one more chip.
private struct GroupChips: View {
    @Binding var selection: StripGroup
    @ScaledMetric private var chipHeight: CGFloat = 36

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(StripGroup.allCases) { group in
                    Button(group.title) { selection = group }
                        .accessibilityAddTraits(selection == group ? .isSelected : [])
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(height: chipHeight)
                        .foregroundStyle(selection == group ? .black : .white)
                        .background(selection == group ? Color.white : Color.clear, in: Capsule())
                        .buttonStyle(.plain)
                }
            }
            .padding(6)
        }
        .glassEffect(.regular.tint(.black), in: Capsule())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#if DEBUG
    #Preview {
        OverviewView(mirror: .preview(), onDisconnect: {})
    }
#endif

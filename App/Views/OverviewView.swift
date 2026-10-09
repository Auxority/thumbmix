import SwiftUI
import ThumbmixCore

struct OverviewView: View {
    let mirror: ConsoleMirror
    let onDisconnect: () -> Void
    @State private var group: StripGroup = .inputs
    @State private var openStrip: StripID?
    @State private var visibleItems: [OverviewItem] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                GroupChips(selection: $group)
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(visibleItems) { item in
                            StripRow(item: item, mirror: mirror) { openStrip = item.opens }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                // Each list gets its own scroll view, so it starts where a list naturally starts. Keeping
                // one left the old offset past a shorter list (only black), and scrolling it to a top
                // anchor shifted the rows on iOS 27. A reconnect keeps the position: no list moves under a finger.
                .id(group)
                .disabled(!mirror.isLive)
                .opacity(mirror.isLive ? 1 : 0.4)
            }
            .background(Theme.background)
            .safeAreaInset(edge: .top, spacing: 0) { StatusBanner(status: mirror.status) }
            .navigationTitle("Thumbmix")
            .demoTitle("Thumbmix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Disconnect", action: onDisconnect) }
            }
            .navigationDestination(item: $openStrip) { strip in
                ChannelView(strip: strip, mirror: mirror)
            }
            .onAppear(perform: refreshVisibleItems)
            .onChange(of: group) { refreshVisibleItems() }
            .onChange(of: mirror.status) { refreshVisibleItems() }
            .onChange(of: linkState) { refreshOnceNoFingerIsDown() }
        }
    }

    /// A link changed on the desk mid-drag would rebuild the row under the finger; the list regroups once it lifts.
    private func refreshOnceNoFingerIsDown() {
        Task {
            while mirror.isFingerDown { try? await Task.sleep(for: .milliseconds(100)) }
            refreshVisibleItems()
        }
    }

    /// Linking or unlinking a pair, here or on the desk, merges or splits rows.
    private var linkState: [OSCArgument?] {
        Catalog.linkAddresses.map { mirror.cell($0).argument }
    }

    /// Rebuilt only when the view, group, connection or links change, never per fader move.
    /// Every strip shows until the Unused toggle's redesign (TODO): hiding them left some out of reach.
    private func refreshVisibleItems() {
        visibleItems = mirror.overviewItems(group.strips, showUnused: true)
    }
}

private struct GroupChips: View {
    @Binding var selection: StripGroup
    @ScaledMetric private var chipHeight: CGFloat = 36

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StripGroup.allCases) { group in
                    Button(group.title) { selection = group }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(height: chipHeight)
                        .foregroundStyle(selection == group ? .black : .white)
                        .background(selection == group ? Color.white : Theme.track, in: Capsule())
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

#if DEBUG
    #Preview {
        OverviewView(mirror: .preview(), onDisconnect: {})
    }
#endif

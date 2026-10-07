import SwiftUI
import ThumbmixCore

struct OverviewView: View {
    private struct ListIdentity: Hashable {
        let group: StripGroup
        let showUnused: Bool
    }

    let mirror: ConsoleMirror
    let onDisconnect: () -> Void
    @State private var group: StripGroup = .inputs
    @State private var showUnused = false
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
                .id(ListIdentity(group: group, showUnused: showUnused))
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Unused") { showUnused.toggle() }
                        .fontWeight(showUnused ? .bold : .regular)
                        .foregroundStyle(showUnused ? .white : Theme.secondaryText)
                        .accessibilityValue(showUnused ? "Shown" : "Hidden")
                }
            }
            .navigationDestination(item: $openStrip) { strip in
                ChannelView(strip: strip, mirror: mirror)
            }
            .onAppear(perform: refreshVisibleItems)
            .onChange(of: group) { refreshVisibleItems() }
            .onChange(of: showUnused) { refreshVisibleItems() }
            .onChange(of: mirror.status) { refreshVisibleItems() }
            .onChange(of: linkState) { refreshVisibleItems() }
        }
    }

    /// Linking or unlinking a pair, here or on the desk, merges or splits rows.
    private var linkState: [OSCArgument?] {
        Catalog.linkAddresses.map { mirror.cell($0).argument }
    }

    /// Filtered only when the view, group, toggle, connection or links change, never per fader move:
    /// a row must not vanish under the finger when an unnamed fader reaches -inf.
    private func refreshVisibleItems() {
        visibleItems = mirror.overviewItems(group.strips, showUnused: showUnused)
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

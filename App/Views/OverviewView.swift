import SwiftUI
import ThumbmixCore

struct OverviewView: View {
    let mirror: ConsoleMirror
    let onDisconnect: () -> Void
    @State private var group: StripGroup = .inputs
    @State private var openStrip: StripID?
    /// The rows as they were when a finger last went down; see `rows`.
    @State private var heldItems: [OverviewItem] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(rows) { item in
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
                // In thumb reach; the list scrolls on under the glass, and its last row scrolls clear of it.
                .safeAreaInset(edge: .bottom, spacing: 0) { GroupChips(selection: $group) }
            }
            .background(Theme.background)
            .safeAreaInset(edge: .top, spacing: 0) { StatusBanner(status: mirror.status) }
            .navigationTitle("Thumbmix")
            .demoTitle("Thumbmix")
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
            .onChange(of: wantedItems, initial: true) { holdItemsUnlessFingerIsDown() }
            .task(id: wantedItems) { await regroupOnceNoFingerIsDown() }
        }
    }

    /// The rows the desk's links call for, computed as the list draws: a cached list missed the last of a status and
    /// link change arriving together and left a linked pair split (2026-10-12, once connect got ~10x faster).
    /// While a finger is down the rows stay as they were: a link changed on the desk mid-drag would rebuild the row
    /// under the finger.
    private var rows: [OverviewItem] { mirror.isFingerDown ? heldItems : wantedItems }

    /// Linking or unlinking a pair, here or on the desk, merges or splits rows. Reads no faders, so it never changes
    /// per fader move. Every strip shows until the Unused toggle's redesign (TODO): hiding them left some out of reach.
    private var wantedItems: [OverviewItem] {
        mirror.overviewItems(group.strips, showUnused: true)
    }

    private func holdItemsUnlessFingerIsDown() {
        if !mirror.isFingerDown { heldItems = wantedItems }
    }

    /// Lifting a finger isn't observed, so a change held back by it is drawn once the finger lifts. The next change or
    /// leaving the screen cancels the wait.
    private func regroupOnceNoFingerIsDown() async {
        while mirror.isFingerDown {
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        }
        heldItems = wantedItems
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

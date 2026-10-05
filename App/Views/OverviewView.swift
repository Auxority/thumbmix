import SwiftUI
import ThumbmixCore

struct OverviewView: View {
    let mirror: ConsoleMirror
    let onDisconnect: () -> Void
    @State private var group: StripGroup = .inputs
    @State private var showUnused = false
    @State private var openStrip: StripID?
    @State private var visibleStrips: [StripID] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                GroupChips(selection: $group)
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(visibleStrips) { strip in
                            StripRow(strip: strip, mirror: mirror) { openStrip = strip }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .disabled(!mirror.isLive)
                .opacity(mirror.isLive ? 1 : 0.4)
            }
            .background(Theme.background)
            .safeAreaInset(edge: .top, spacing: 0) { StatusBanner(status: mirror.status) }
            .navigationTitle("Thumbmix")
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
            .onAppear(perform: refreshVisibleStrips)
            .onChange(of: group) { refreshVisibleStrips() }
            .onChange(of: showUnused) { refreshVisibleStrips() }
            .onChange(of: mirror.status) { refreshVisibleStrips() }
        }
    }

    /// Filtered only when the view, group, toggle or connection changes, never per fader move:
    /// a row must not vanish under the finger when an unnamed fader reaches -inf.
    private func refreshVisibleStrips() {
        visibleStrips = group.strips.filter { showUnused || !mirror.isUnused($0) }
    }
}

private struct GroupChips: View {
    @Binding var selection: StripGroup

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StripGroup.allCases) { group in
                    Button(group.title) { selection = group }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .foregroundStyle(selection == group ? .black : .white)
                        .background(selection == group ? Color.white : Theme.track, in: Capsule())
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

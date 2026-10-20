import SwiftUI
import ThumbmixCore

/// What a folded line opens: the block's controls, as on the tab (mock B, 2026-10-20).
struct FoldSheet<Content: View>: View {
    let title: String
    let mirror: ConsoleMirror
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) { content }
                    .padding(16)
                    .disabled(!mirror.isLive)
                    .opacity(mirror.isLive ? 1 : 0.4)
            }
            // The sheet covers the tab's banner: it says itself when contact is lost.
            .safeAreaInset(edge: .top, spacing: 0) { StatusBanner(status: mirror.status) }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold).buttonStyle(.darkCapsule)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }
}

extension View {
    /// Like `sendSheetPresentation`: at medium height the fader and mute above stay usable.
    func foldSheetPresentation(_ detents: Set<PresentationDetent>) -> some View {
        presentationDetents(detents)
            .presentationBackgroundInteraction(detents.contains(.medium) ? .enabled(upThrough: .medium) : .automatic)
            .presentationBackground { Color.clear.glassEffect(.regular.tint(.black), in: .rect) }
    }
}

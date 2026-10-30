import SwiftUI
import ThumbmixCore

extension EnvironmentValues {
    /// Set once by the root, so every screen reaches the one library. nil only where nothing sets it (a preview).
    @Entry var presetLibrary: PresetLibrary?
    /// Where a load that went out is told, so the edit sheet can close onto the strip. The sheet's own object, not a
    /// closure: a new closure on every redraw of the sheet would redraw every page reading it.
    @Entry var presetLoads: PresetLoads?
}

/// Counts the loads that went out; the edit sheet closes on a change.
@Observable final class PresetLoads {
    private(set) var count = 0
    func loaded() { count += 1 }
}

/// A message the engineer must read: what went wrong, or what just happened. One alert for all of a screen's.
private struct NoticeAlert: ViewModifier {
    @Binding var notice: String?
    @State private var isShowing = false

    func body(content: Content) -> some View {
        content
            // An alert ignores a new one while it still animates out (CLAUDE.md), and most notices answer a button of
            // another alert: the notice waits 0.4 s, or the engineer would see nothing happen.
            .onChange(of: notice) {
                guard notice != nil else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    isShowing = notice != nil
                }
            }
            .alert("Presets", isPresented: $isShowing) {
                Button("OK") { notice = nil }
            } message: {
                Text(verbatim: notice ?? "")
            }
    }
}

extension View {
    func noticeAlert(_ notice: Binding<String?>) -> some View { modifier(NoticeAlert(notice: notice)) }

    /// Presets are the one place the edit sheet's pages must work without a desk: Import, Share, Edit and Sources
    /// don't need one, so the screens re-enable themselves and disable what writes to the desk (as `FoldSheet` does).
    func presetPage(_ mirror: ConsoleMirror) -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
            .safeAreaInset(edge: .top, spacing: 0) { StatusBanner(mirror: mirror) }
            .environment(\.isEnabled, true)
    }
}

struct SharedPreset: Identifiable {
    let url: URL
    var id: URL { url }
}

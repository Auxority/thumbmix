import SwiftUI
import ThumbmixCore

/// Reads the status in its own body: the screen it sits on then doesn't redraw for each percent of the sync, which
/// cost the overview ~1 s per connect (2026-10-23).
struct StatusBanner: View {
    let mirror: ConsoleMirror

    var body: some View {
        StatusText(status: mirror.status)
    }
}

private struct StatusText: View {
    let status: MirrorStatus

    var body: some View {
        switch status {
        case .live, .failed:
            EmptyView()
        case .connecting:
            banner("Connecting…", Theme.raised)
        case .syncing(let progress):
            banner("Syncing \(Int(progress * 100))%", Color(red: 0.2, green: 0.35, blue: 0.8))
        case .lost:
            banner("Disconnected — retrying", Theme.muteRed)
        }
    }

    private func banner(_ text: LocalizedStringKey, _ color: Color) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color)
    }
}

#if DEBUG
    #Preview {
        VStack(spacing: 0) {
            StatusText(status: .connecting)
            StatusText(status: .syncing(0.42))
            StatusText(status: .lost)
        }
    }
#endif

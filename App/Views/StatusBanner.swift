import SwiftUI
import ThumbmixCore

struct StatusBanner: View {
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
            StatusBanner(status: .connecting)
            StatusBanner(status: .syncing(0.42))
            StatusBanner(status: .lost)
        }
    }
#endif

import SwiftUI
import ThumbmixCore

/// A strip's tabs as chips along the bottom edge, in thumb reach. All of them stay visible: six chips are
/// ≈ 55 pt wide on a 375 pt screen. A seventh tab would need a scrolling row instead (TODO.md).
struct StripTabBar: View {
    let tabs: [ChannelTab]
    @Binding var selection: ChannelTab
    @ScaledMetric private var height: CGFloat = 44

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs) { chip($0) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.background)
        .overlay(alignment: .top) { Divider() }
    }

    private func chip(_ tab: ChannelTab) -> some View {
        let isSelected = tab == selection
        return Button {
            selection = tab
        } label: {
            Text(tab.title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? .white : Theme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(isSelected ? Theme.selected : Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

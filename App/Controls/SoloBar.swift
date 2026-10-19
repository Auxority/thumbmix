import SwiftUI
import ThumbmixCore

/// Above the overview's tabs while anything on the desk is soloed (2026-10-19), from the app, the desk or another app:
/// how many, and Clear, in thumb reach. Clear is the desk's own CLEAR SOLO.
struct SoloBar: View {
    let mirror: ConsoleMirror

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.soloYellow).frame(width: 8, height: 8)
            Text("\(mirror.soloedCount) soloed")
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("solo-bar")
            Spacer(minLength: 8)
            Button("Clear", action: mirror.clearSolo)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .background(.white.opacity(0.14), in: Capsule())
                .buttonStyle(.plain)
                .accessibilityIdentifier("clear-solo")
                .accessibilityLabel("Clear solo")
        }
        .padding(.leading, 18)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        .glassEffect(.regular.tint(.black), in: Capsule())
        .padding(.horizontal, 12)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

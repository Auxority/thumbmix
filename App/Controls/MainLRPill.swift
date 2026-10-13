import SwiftUI
import ThumbmixCore

/// "To Main LR" on the Mix tab's name line (mock 2026-10-13). Taking a strip out can drop a vocal from the PA, and
/// putting one in can send a click or talkback there, so every tap asks first, both ways.
struct MainLRPill: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var isAsking = false
    @ScaledMetric private var width: CGFloat = 74
    @ScaledMetric private var height: CGFloat = 32
    @ScaledMetric private var iconWidth: CGFloat = 20

    var body: some View {
        let inMix = mirror.isInMainLR(strip)
        Button {
            isAsking = true
        } label: {
            // A fixed icon slot and width: the pill never resizes when it flips.
            HStack(spacing: 6) {
                Image(systemName: inMix == false ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: iconWidth)
                    .opacity(inMix == nil ? 0 : 1)
                Text("LR")
            }
            .font(.subheadline.bold())
            .frame(width: width, height: height)
            .foregroundStyle(inMix == true ? Theme.usualOnGreen : Theme.offText)
            .background(inMix == true ? Theme.usualOnTint : Theme.raised, in: Capsule())
        }
        .buttonStyle(.plain)
        // Unread: no state is shown, so nothing can be switched from a guess.
        .disabled(inMix == nil)
        .accessibilityIdentifier("mainLR-" + (strip.mainLR ?? ""))
        .accessibilityLabel(inMix == false ? "\(name) out of the main mix" : "\(name) in the main mix")
        .alert(inMix == false ? "Send \(name) to the main mix?" : "Take \(name) out of the main mix?", isPresented: $isAsking) {
            if inMix == false {
                Button("Send to LR") { mirror.setInMainLR(strip, true) }
            } else {
                Button("Take out", role: .destructive) { mirror.setInMainLR(strip, false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                inMix == false
                    ? "\(name) will be heard in Main LR at its fader level." : "\(name) stops reaching Main LR. Its sends keep working.")
        }
    }

    private var name: String { mirror.isLinked(strip) ? mirror.pairName(strip) : mirror.name(strip) }
}

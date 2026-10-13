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

    var body: some View {
        let inMix = mirror.isInMainLR(strip)
        Button {
            isAsking = true
        } label: {
            MainLRLabel(inMix: inMix)
                .font(.subheadline.bold())
                .frame(width: width, height: height)
                .foregroundStyle(inMix == true ? Theme.usualOnGreen : Theme.offText)
                .background(inMix == true ? Theme.usualOnTint : Theme.raised, in: Capsule())
        }
        .buttonStyle(.plain)
        .mainLRSwitch(strip, mirror: mirror, isAsking: $isAsking)
    }
}

/// The LR switch of a row on Main LR's Fed by (mock A, 2026-10-13): shaped like the On chips of the other Fed by
/// rows, and asking first like the pill, since a stray tap while scrolling is easier here.
struct MainLRChip: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var isAsking = false
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let inMix = mirror.isInMainLR(strip)
        Button {
            isAsking = true
        } label: {
            MainLRLabel(inMix: inMix)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 52 * sizeScale, minHeight: 44 * sizeScale)
                .padding(.horizontal, 8)
                .foregroundStyle(inMix == true ? Theme.usualOnGreen : Theme.secondaryText)
                .background(inMix == true ? Theme.usualOnTint : Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .mainLRSwitch(strip, mirror: mirror, isAsking: $isAsking)
    }
}

/// A speaker, or a crossed one when out: the icon, not colour alone, tells the state.
private struct MainLRLabel: View {
    let inMix: Bool?
    @ScaledMetric private var iconWidth: CGFloat = 20

    var body: some View {
        // A fixed icon slot: the label never resizes when it flips.
        HStack(spacing: 6) {
            Image(systemName: inMix == false ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .frame(width: iconWidth)
                .opacity(inMix == nil ? 0 : 1)
            Text("LR")
        }
    }
}

extension View {
    /// The pill's and the chip's shared behaviour: unread, nothing can be switched from a guess; read, a tap asks.
    fileprivate func mainLRSwitch(_ strip: StripID, mirror: ConsoleMirror, isAsking: Binding<Bool>) -> some View {
        let inMix = mirror.isInMainLR(strip)
        let name = mirror.isLinked(strip) ? mirror.pairName(strip) : mirror.name(strip)
        return
            self
            .disabled(inMix == nil)
            .accessibilityIdentifier("mainLR-" + (strip.mainLR ?? ""))
            .accessibilityLabel(inMix == false ? "\(name) out of the main mix" : "\(name) in the main mix")
            .alert(
                inMix == false ? "Send \(name) to the main mix?" : "Take \(name) out of the main mix?", isPresented: isAsking
            ) {
                if inMix == false {
                    Button("Send to LR") { mirror.setInMainLR(strip, true) }
                } else {
                    Button("Take out", role: .destructive) { mirror.setInMainLR(strip, false) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    inMix == false
                        ? "\(name) will be heard in Main LR at its fader level." : "\(name) stops reaching Main LR. Its sends keep working."
                )
            }
    }
}

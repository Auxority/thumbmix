import SwiftUI
import ThumbmixCore

/// Ø beside Trim, like 48V beside Gain (mock A, 2026-10-12). Amber when flipped: it changes the sound but harms nothing,
/// so it isn't red. It asks first, and the alert says what polarity does, since few people know the symbol.
struct PolarityButton: View {
    let spec: ParamSpec
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var isConfirming = false
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let state = mirror.cell(spec.address).argument
        let isFlipped = state == .int(1)
        let prompt = PolarityPrompt(
            name: mirror.name(strip), isFlipped: isFlipped,
            partner: mirror.gainDelayPartner(of: strip).map { mirror.name($0) })
        Button {
            isConfirming = true
        } label: {
            Text(verbatim: "Ø")
                .font(.title2.weight(.medium))
                .frame(width: 64 * sizeScale, height: 48 * sizeScale)
                .foregroundStyle(isFlipped ? .black : Theme.secondaryText)
                .background(isFlipped ? Theme.polarityAmber : Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .dimmedUntilRead(state != nil)
        .accessibilityIdentifier("toggle-" + spec.address)
        .accessibilityLabel(Text("Polarity"))
        .accessibilityValue(state == nil ? Text(verbatim: "") : isFlipped ? Text("Flipped") : Text("Normal"))
        .alert(prompt.title, isPresented: $isConfirming) {
            Button("Cancel", role: .cancel) {}
            Button(prompt.confirm) { mirror.set(spec.address, .int(isFlipped ? 0 : 1)) }
        } message: {
            if let message = prompt.message { Text(verbatim: message) }
        }
    }
}

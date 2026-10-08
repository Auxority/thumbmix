import SwiftUI
import ThumbmixCore

/// The one control in the app: drag anywhere on the row, relative to where the value was.
struct ParameterRow: View {
    let spec: ParamSpec
    let mirror: ConsoleMirror
    var title: String?
    var accent: Color = .white
    var height: CGFloat = 48
    var meter: MeterCell?
    /// A linked pair's left side, drawn above `meter` (the right side).
    var upperMeter: MeterCell?
    /// Under the reset question: who else the reset reaches, e.g. a linked partner.
    var resetNote: String?

    @State private var dragStart: Float?
    @State private var unityTicks = 0
    @State private var isConfirmingReset = false
    /// Grows the row with the user's text size, so large type isn't clipped.
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let position = mirror.normalized(spec)
        let text = ValueText.format(position, spec)
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10).fill(Theme.track)
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(accent.opacity(dragStart == nil ? 0.28 : 0.45))
                        .frame(width: geometry.size.width * CGFloat(position ?? 0))
                    if let meter { MeterLine(cell: meter, width: geometry.size.width) }
                    if let upperMeter { MeterLine(cell: upperMeter, width: geometry.size.width).padding(.bottom, 5) }
                }
            }
            HStack {
                Text(title ?? spec.label)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                Text(text)
                    .font(
                        dragStart == nil
                            ? .body.monospacedDigit().weight(.semibold) : .title2.monospacedDigit().weight(.bold)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 12)
            .allowsHitTesting(false)
            HorizontalPanArea(onBegan: beginDrag, onChanged: drag, onEnded: endDrag, onDoubleTap: reset)
        }
        .frame(height: height * sizeScale)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .sensoryFeedback(.selection, trigger: unityTicks)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(spec.address)
        .accessibilityLabel(title.flatMap { $0.isEmpty ? nil : $0 } ?? spec.label)
        .accessibilityValue(text)
        .accessibilityAdjustableAction(adjust)
        .alert(Text(verbatim: spec.resetPrompt ?? ""), isPresented: $isConfirmingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive, action: applyReset)
        } message: {
            if let resetNote { Text(verbatim: resetNote) }
        }
    }

    /// VoiceOver swipe up/down: dragging isn't available to a VoiceOver user, so the row steps instead.
    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        guard let current = mirror.normalized(spec) else { return }
        let step =
            switch direction {
            case .increment: 1
            case .decrement: -1
            @unknown default: 0
            }
        guard step != 0 else { return }
        mirror.set(
            spec.address,
            spec.scale.argument(
                fromNormalized: RelativeDrag.stepped(current, by: step, scale: spec.scale)))
    }

    /// No value read yet means no drag: starting from a guess would jump the desk.
    private func beginDrag() {
        guard let current = mirror.normalized(spec) else { return }
        dragStart = current
        mirror.beginEdit(spec.address)
    }

    private func endDrag() {
        guard dragStart != nil else { return }
        dragStart = nil
        mirror.endEdit(spec.address)
    }

    private func drag(_ translation: CGFloat, _ width: CGFloat) {
        guard let dragStart else { return }
        let old = mirror.normalized(spec) ?? dragStart
        let new = RelativeDrag.value(
            start: dragStart, translation: translation, width: width, scale: spec.scale)
        guard new != old else { return }
        if let unity = spec.unityNormalized, RelativeDrag.crossed(unity, from: old, to: new) {
            unityTicks += 1
        }
        mirror.set(spec.address, spec.scale.argument(fromNormalized: new))
    }

    /// A spec with a reset prompt asks first: a double-tap is as easy to hit by accident as a drag.
    private func reset() {
        guard spec.resetValue != nil else { return }
        if spec.resetPrompt == nil { applyReset() } else { isConfirmingReset = true }
    }

    private func applyReset() {
        guard let value = spec.resetValue else { return }
        mirror.set(
            spec.address, spec.scale.argument(fromNormalized: spec.scale.normalized(forValue: value)))
    }
}

/// A separate view so 20 Hz meter updates redraw this line only, not the row.
private struct MeterLine: View {
    let cell: MeterCell
    let width: CGFloat

    var body: some View {
        Capsule()
            .fill(MeterBar.color(for: cell.level))
            .frame(width: width * MeterScale.fraction(linear: cell.level), height: 3)
            .padding(.bottom, 2)
    }
}

#if DEBUG
    #Preview {
        let mirror = ConsoleMirror.preview()
        return VStack(spacing: 8) {
            ParameterRow(
                spec: Catalog.fader(StripID(.input, 1)), mirror: mirror, accent: .red, height: 72,
                meter: mirror.meter(StripID(.input, 1)))
            ParameterRow(spec: Catalog.gate(StripID(.input, 1)).threshold, mirror: mirror)
        }
        .padding()
        .background(Theme.background)
    }
#endif

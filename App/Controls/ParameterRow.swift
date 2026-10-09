import SwiftUI
import ThumbmixCore

/// The one control in the app: drag anywhere on the row, relative to where the value was, or hold it to type a value.
struct ParameterRow: View {
    let spec: ParamSpec
    let mirror: ConsoleMirror
    var title: String?
    var accent: Color = .white
    var height: CGFloat = 48
    var meter: MeterCell?
    /// A linked pair's left side, drawn above `meter` (the right side).
    var upperMeter: MeterCell?

    /// Where the drag has taken the value, unsnapped: slow movements add up even below one desk step.
    @State private var dragPosition: Float?
    @State private var dragSpeed = 1.0
    @State private var unityTicks = 0
    @State private var isTyping = false
    /// `.disabled` doesn't reach the UIKit pan area, so the row checks it itself.
    @Environment(\.isEnabled) private var isEnabled
    /// Grows the row with the user's text size, so large type isn't clipped.
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        // A disabled row shows no value: a number would suggest it still does something.
        let position = isEnabled ? mirror.normalized(spec) : nil
        let text = ValueText.format(position, spec)
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10).fill(Theme.track)
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(accent.opacity(dragPosition == nil ? 0.28 : 0.45))
                        .frame(width: geometry.size.width * CGFloat(position ?? 0))
                    if let meter { MeterLine(cell: meter, width: geometry.size.width) }
                    if let upperMeter { MeterLine(cell: upperMeter, width: geometry.size.width).padding(.bottom, 5) }
                }
            }
            HStack {
                Text(speedLabel ?? title ?? spec.label)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                Text(text)
                    .font(
                        dragPosition == nil
                            ? .body.monospacedDigit().weight(.semibold) : .title2.monospacedDigit().weight(.bold)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 12)
            .allowsHitTesting(false)
            HorizontalPanArea(
                onBegan: beginDrag, onMoved: drag, onEnded: endDrag, onDoubleTap: reset, onHold: startTyping)
        }
        .frame(height: height * sizeScale)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isEnabled ? 1 : 0.38)
        .sensoryFeedback(.selection, trigger: unityTicks)
        .sensoryFeedback(.selection, trigger: dragSpeed)
        .sensoryFeedback(.impact(weight: .light), trigger: isTyping) { _, opened in opened }
        .modifier(TypeValueAlert(spec: spec, title: alertTitle, mirror: mirror, isPresented: $isTyping))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(spec.address)
        .accessibilityLabel(title.flatMap { $0.isEmpty ? nil : $0 } ?? spec.label)
        .accessibilityValue(text)
        .accessibilityAdjustableAction(adjust)
        .accessibilityAction(named: "Enter value", startTyping)
    }

    private var alertTitle: String { title.flatMap { $0.isEmpty ? nil : $0 } ?? spec.label }

    /// While a drag is slowed by straying from the row, the label says how much.
    private var speedLabel: String? {
        switch dragSpeed {
        case 0.5: String(localized: "½ speed")
        case 0.25: String(localized: "¼ speed")
        default: nil
        }
    }

    /// Like a drag, nothing to type over before the desk has sent the value.
    private func startTyping() {
        guard isEnabled, mirror.normalized(spec) != nil else { return }
        isTyping = true
    }

    /// VoiceOver swipe up/down: dragging isn't available to a VoiceOver user, so the row steps instead.
    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        guard isEnabled, let current = mirror.normalized(spec) else { return }
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
        guard isEnabled, let current = mirror.normalized(spec) else { return }
        dragPosition = current
        mirror.beginEdit(spec.address)
    }

    private func endDrag() {
        guard dragPosition != nil else { return }
        dragPosition = nil
        dragSpeed = 1
        mirror.endEdit(spec.address)
    }

    private func drag(_ distance: CGFloat, _ width: CGFloat, _ outside: CGFloat) {
        guard let position = dragPosition else { return }
        dragSpeed = RelativeDrag.speed(outside: outside, rowHeight: height * sizeScale)
        let moved = RelativeDrag.moved(position, by: distance, width: width, speed: dragSpeed)
        dragPosition = moved
        let old = mirror.normalized(spec) ?? position
        let new = spec.scale.snap(moved)
        guard new != old else { return }
        if let unity = spec.unityNormalized, RelativeDrag.crossed(unity, from: old, to: new) {
            unityTicks += 1
        }
        mirror.set(spec.address, spec.scale.argument(fromNormalized: new))
    }

    private func reset() {
        guard isEnabled, let value = spec.resetValue else { return }
        mirror.set(
            spec.address, spec.scale.argument(fromNormalized: spec.scale.normalized(forValue: value)))
    }
}

/// The system alert a held row opens: the current value as placeholder, the range as message. A number past either
/// end lands on that end (Set is the confirmation); text that isn't a value reopens the alert saying so.
private struct TypeValueAlert: ViewModifier {
    let spec: ParamSpec
    let title: String
    let mirror: ConsoleMirror
    @Binding var isPresented: Bool
    @State private var typed = ""
    /// What was typed when Set found no value in it; kept so the reopened alert shows it and the text stays.
    @State private var refused: String?

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                TextField(ValueText.format(mirror.normalized(spec), spec), text: $typed)
                    .keyboardType(.numbersAndPunctuation)
                Button("Cancel", role: .cancel) { refused = nil }
                // Never .disabled: a disabled state that changes while typing makes Set lose its action (iOS 27).
                Button("Set", action: set)
            } message: {
                if let refused {
                    Text("“\(refused)” isn't a value. \(ValueInput.rangeText(spec))")
                } else {
                    Text(ValueInput.rangeText(spec))
                }
            }
            .onChange(of: isPresented) { _, isOpen in isOpen ? opened() : closed() }
    }

    private func set() {
        guard let value = ValueInput.normalized(from: typed, for: spec) else {
            refused = typed
            return
        }
        refused = nil
        mirror.set(spec.address, spec.scale.argument(fromNormalized: value))
    }

    private func opened() {
        if refused == nil { typed = "" }
    }

    /// Reopening while the alert still animates out is ignored, so it waits for the dismissal to finish.
    private func closed() {
        guard refused != nil else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isPresented = true
        }
    }
}

/// A separate view so 20 Hz meter updates redraw this line only, not the row.
private struct MeterLine: View {
    let cell: MeterCell
    let width: CGFloat

    var body: some View {
        Capsule()
            .fill(Self.color(for: cell.level))
            .frame(width: width, height: 3)
            .meterFill(MeterScale.fraction(linear: cell.level), from: .leading)
            .padding(.bottom, 2)
    }

    private static func color(for level: Float) -> Color {
        switch MeterScale.decibels(level) {
        case ..<(-12): .green
        case ..<(-3): .yellow
        default: .red
        }
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

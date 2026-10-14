import SwiftUI
import ThumbmixCore

/// A strip's insert under Pan (mock A′, 2026-10-14). The slot row sits where a Slot menu goes once m32-probe tells
/// what taking a held slot does, so making it editable moves nothing.
struct InsertBlock: View {
    /// One strip, or both sides of a pair the desk links (odd side first): edits go to the first.
    let sides: [StripID]
    let mirror: ConsoleMirror
    /// "Insert · Gtr L" when a pair shows one block per side.
    var title: String?

    var body: some View {
        if let spec = Catalog.insert(sides[0]) {
            let slots = sides.compactMap(mirror.insertSlot)
            // Unread (slot, On or Position) counts as neither empty nor set: controls stay disabled, no note claims anything.
            let isRead = mirror.isInsertRead(sides)
            let isEmpty = isRead && slots.allSatisfy { $0 == .none }
            VStack(alignment: .leading, spacing: 8) {
                Text(title ?? String(localized: "Insert"))
                    .font(.footnote).textCase(.uppercase).foregroundStyle(Theme.secondaryText)
                SlotRow(spec: spec.slot, text: mirror.insertLabel(sides))
                HStack(spacing: 8) {
                    InsertChip(spec: spec.on, sides: sides, slots: slots, mirror: mirror)
                    ChoiceMenu(spec: spec.position, mirror: mirror)
                }
                .disabled(!isRead || isEmpty)
                if isRead {
                    Text(isEmpty ? "No slot picked on the desk" : "Set on the desk")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }
}

/// Outlined and without a chevron: it doesn't look tappable, because it isn't yet.
private struct SlotRow: View {
    let spec: ParamSpec
    let text: String?
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        HStack {
            Text(spec.label).font(.subheadline).foregroundStyle(Theme.secondaryText)
            Spacer(minLength: 8)
            Text(verbatim: text ?? "—").font(.body.weight(.semibold)).foregroundStyle(.white)
                .minimumScaleFactor(0.8)
        }
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 48 * sizeScale)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.track))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spec.label)
        .accessibilityValue(text ?? "")
        .accessibilityIdentifier(spec.address)
    }
}

/// Green when on, like the delay's chip. Switching on an aux slot asks first (`InsertPrompt`).
private struct InsertChip: View {
    let spec: ParamSpec
    let sides: [StripID]
    let slots: [InsertSlot]
    let mirror: ConsoleMirror
    @State private var prompt: InsertPrompt?
    @State private var isAsking = false
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let isOn = mirror.cell(spec.address).argument == .int(1)
        Button {
            let name = sides.count == 2 ? mirror.pairName(sides[0]) : mirror.name(sides[0])
            prompt = InsertPrompt(name: name, turningOn: !isOn, slots: slots)
            if prompt == nil { mirror.set(spec.address, .int(isOn ? 0 : 1)) } else { isAsking = true }
        } label: {
            Text(spec.label)
                .font(.subheadline.weight(.semibold))
                .frame(width: 84 * sizeScale, height: 48 * sizeScale)
                .foregroundStyle(isOn ? .black : Theme.secondaryText)
                .background(isOn ? Color.green : Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("toggle-" + spec.address)
        .accessibilityValue(isOn ? "On" : "Off")
        .alert(prompt?.title ?? "", isPresented: $isAsking) {
            Button("Cancel", role: .cancel) {}
            Button(prompt?.confirm ?? "") { mirror.set(spec.address, .int(1)) }
        } message: {
            Text(verbatim: prompt?.message ?? "")
        }
    }
}

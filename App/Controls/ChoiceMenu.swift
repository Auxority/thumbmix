import SwiftUI
import ThumbmixCore

/// A dropdown for a choice parameter, styled like `ParameterRow`: picking from a visible list beats
/// dragging through options you can't see. Disabled until the console sent the current value.
struct ChoiceMenu: View {
    let spec: ParamSpec
    let mirror: ConsoleMirror
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let position = mirror.normalized(spec)
        let current = position.map { Int(spec.scale.value(fromNormalized: $0)) }
        let text = ValueText.format(position, spec)
        Menu {
            ForEach(options.indices, id: \.self) { option in
                Button {
                    select(option)
                } label: {
                    item(option, isCurrent: option == current)
                }
            }
        } label: {
            HStack {
                Text(spec.label).font(.subheadline).foregroundStyle(Theme.secondaryText)
                Spacer(minLength: 8)
                Text(text).font(.body.weight(.semibold)).foregroundStyle(.white)
                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 48 * sizeScale)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .disabled(current == nil)
        .accessibilityIdentifier(spec.address)
        .accessibilityValue(text)
    }

    /// The option in words with the desk's name under it, so the list explains and the closed row matches the desk.
    @ViewBuilder private func item(_ option: Int, isCurrent: Bool) -> some View {
        let name = spec.optionNames?[option] ?? options[option]
        // A menu item reads a second Text as its subtitle; inside a Label's title it's dropped.
        Text(verbatim: name)
        if spec.optionNames != nil { Text(verbatim: options[option]) }
        if isCurrent { Image(systemName: "checkmark") }
    }

    private var options: [String] {
        if case .choice(let options) = spec.scale { options } else { [] }
    }

    private func select(_ option: Int) {
        mirror.set(spec.address, spec.scale.argument(fromNormalized: spec.scale.normalized(forValue: Double(option))))
    }
}

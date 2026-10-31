import SwiftUI
import ThumbmixCore

/// A name's text field with its n/12 counter, typed under a strip name's rules: the edit sheet's, and a mute group's.
struct NameField: View {
    let title: LocalizedStringKey
    let placeholder: String
    @Binding var name: String
    var identifier = "strip-name"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title)
            HStack {
                TextField(placeholder, text: $name)
                    .accessibilityIdentifier(identifier)
                    .autocorrectionDisabled()
                    .onChange(of: name) { _, typed in
                        let allowed = StripName.typed(typed)
                        if allowed != typed { name = allowed }
                    }
                Text("\(name.count)/\(StripName.maxLength)").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .padding(12)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

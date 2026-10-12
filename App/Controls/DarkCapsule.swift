import SwiftUI

/// A near-black capsule for the buttons iOS would fill grey (toolbar glass, Connect), so the screen stays OLED dark.
/// Glass tinted black keeps the system's rim and press effect and sits with iOS's back button, which can't be
/// restyled. A prominent button fills white while enabled.
struct DarkCapsuleStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let isFilled = prominent && isEnabled
        return configuration.label
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .foregroundStyle(isFilled ? Color.black : isEnabled ? Color.white : Theme.secondaryText)
            .glassEffect(.regular.tint(isFilled ? .white : .black).interactive(), in: Capsule())
            // iOS 27's bar measured the capsule too narrow ("D…" for Disconnect), as it did the DEMO pill.
            .fixedSize()
    }
}

extension ButtonStyle where Self == DarkCapsuleStyle {
    static var darkCapsule: DarkCapsuleStyle { DarkCapsuleStyle() }
    static var prominentDarkCapsule: DarkCapsuleStyle { DarkCapsuleStyle(prominent: true) }
}

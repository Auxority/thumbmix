public enum ChannelTab: String, CaseIterable, Identifiable, Sendable {
    case mix = "Mix"
    case input = "Input"
    case gate = "Gate"
    case eq = "EQ"
    case comp = "Comp"
    case sends = "Sends"
    case fedBy = "Fed by"
    case members = "Members"

    public var id: Self { self }

    /// The catalog key; also the English title.
    public var titleKey: String { rawValue }

    public var title: String { CoreStrings.text(String.LocalizationValue(titleKey)) }

    /// Every strip opens on Mix: its full fader, nudges, mute and pan. The other tabs keep a slim fader and mute.
    public static func tabs(for kind: StripKind) -> [ChannelTab] {
        switch kind {
        case .input: [.mix, .input, .gate, .eq, .comp, .sends]
        case .bus: [.mix, .eq, .comp, .fedBy]
        case .mainStereo, .mainMono: [.mix, .eq, .comp]
        case .dca: [.mix, .members]
        case .auxIn, .fxReturn: [.mix]
        }
    }
}

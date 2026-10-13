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

    /// The Link Preference that decides whether a linked pair shows this tab once or per side.
    public var linkSection: LinkSection? {
        switch self {
        case .mix, .sends: .faderMute
        case .input: .gainDelay
        case .eq: .eq
        case .gate, .comp: .dynamics
        case .fedBy, .members: nil
        }
    }

    /// The order strips in use are read in the background (the user, 2026-10-12): what an FOH engineer opens most
    /// comes first. Mix and Members show only what connect already read.
    public static let fillOrder: [ChannelTab] = [.input, .eq, .comp, .sends, .gate, .fedBy]

    /// Every strip opens on Mix: its full fader, nudges, mute and pan. The other tabs keep a slim fader and mute.
    /// A bus's Sends (to the matrices) sit before Fed by, which mix buses use more and so keeps the far right.
    public static func tabs(for kind: StripKind) -> [ChannelTab] {
        switch kind {
        case .input: [.mix, .input, .gate, .eq, .comp, .sends]
        case .bus: [.mix, .eq, .comp, .sends, .fedBy]
        case .matrix: [.mix, .eq, .comp, .fedBy]
        case .mainStereo, .mainMono: [.mix, .eq, .comp, .sends]
        case .dca: [.mix, .members]
        case .auxIn: [.mix, .input, .eq, .sends]
        case .fxReturn: [.mix, .eq, .sends]
        }
    }
}

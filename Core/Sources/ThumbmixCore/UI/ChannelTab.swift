public enum ChannelTab: String, CaseIterable, Identifiable, Sendable {
    case input = "Input", gate = "Gate", eq = "EQ", comp = "Comp", sends = "Sends", fedBy = "Fed by", members = "Members"

    public var id: Self { self }

    public static func tabs(for kind: StripKind) -> [ChannelTab] {
        switch kind {
        case .input: [.input, .gate, .eq, .comp, .sends]
        case .bus: [.eq, .comp, .fedBy]
        case .mainStereo, .mainMono: [.eq, .comp]
        case .dca: [.members]
        case .auxIn, .fxReturn: []
        }
    }
}

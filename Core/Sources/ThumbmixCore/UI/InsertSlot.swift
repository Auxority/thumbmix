/// What `insert/sel` (doc p.26) names: no slot, one side of an FX engine, or an aux out to outboard gear.
public enum InsertSlot: Equatable, Sendable {
    case none
    case fx(Int, right: Bool)
    case aux(Int)

    /// nil for a value outside the desk's 0…22: shown as unread, never guessed.
    public init?(sel: Int) {
        switch sel {
        case 0: self = .none
        case 1...16: self = .fx((sel - 1) / 2 + 1, right: (sel - 1) % 2 == 1)
        case 17...22: self = .aux(sel - 16)
        default: return nil
        }
    }

    public var fx: Int? {
        if case .fx(let number, _) = self { number } else { nil }
    }

    /// The slot alone: "FX5 L", "Aux out 1", "None".
    public var short: String {
        switch self {
        case .none: CoreStrings.text("None")
        case .fx(let number, let right): right ? "FX\(number) R" : "FX\(number) L"
        case .aux(let number): CoreStrings.text("Aux out \(number)")
        }
    }

    /// The Slot row: "FX5 L · Dual DeEsser"; an FX whose type isn't read yet shows the slot alone.
    public func label(effect: String?) -> String {
        switch self {
        case .none: short
        case .fx: effect.map { short + " · " + $0 } ?? short
        case .aux: short + " · " + CoreStrings.text("outboard")
        }
    }

    /// A linked pair usually holds both halves of one FX: "FX5 L / R · Dual DeEsser". Anything else names both.
    public static func pairLabel(_ odd: InsertSlot, _ even: InsertSlot, effect: (Int) -> String?) -> String {
        if odd == even { return odd.label(effect: odd.fx.flatMap(effect)) }
        if case .fx(let number, right: false) = odd, even == .fx(number, right: true) {
            return (effect(number).map { "FX\(number) L / R · " + $0 }) ?? "FX\(number) L / R"
        }
        return odd.short + " / " + even.short
    }
}

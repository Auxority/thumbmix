import Foundation

/// Odd/even stereo pairs. The desk can link inputs, aux ins, FX returns, buses and matrices (doc p.19);
/// matrices join once the app shows them.
extension StripID {
    /// The desk's link switch for this strip's pair, nil where the desk can't link.
    public var linkAddress: String? {
        guard let group = linkGroup else { return nil }
        return "/config/\(group)/\(oddSide.number)-\(oddSide.number + 1)"
    }

    public var partner: StripID? {
        guard linkGroup != nil else { return nil }
        return StripID(kind, number.isMultiple(of: 2) ? number - 1 : number + 1)
    }

    /// The odd side opens and names the pair, like the desk's link button on the odd channel.
    public var oddSide: StripID {
        number.isMultiple(of: 2) ? StripID(kind, number - 1) : self
    }

    public var pairDefaultName: String {
        let odd = oddSide.number
        let even = odd + 1
        switch kind {
        case .auxIn: return CoreStrings.text("Aux \(odd)-\(even)")
        case .fxReturn: return CoreStrings.text("FX \(odd)-\(even)")
        case .bus: return CoreStrings.text("Bus \(odd)-\(even)")
        default: return CoreStrings.text("Ch \(odd)-\(even)")
        }
    }

    /// The linkable strip an address belongs to and the part after its prefix: "/ch/09/eq/2/g" → (Ch 9, "/eq/2/g").
    public static func linkable(from address: String) -> (strip: StripID, suffix: String)? {
        let parts = address.split(separator: "/", maxSplits: 2)
        guard parts.count == 3, let kind = kindsByPath[String(parts[0])], let number = Int(parts[1]),
            (1...kind.count).contains(number)
        else { return nil }
        return (StripID(kind, number), "/" + parts[2])
    }

    private static let kindsByPath: [String: StripKind] = [
        "ch": .input, "auxin": .auxIn, "fxrtn": .fxReturn, "bus": .bus,
    ]

    private var linkGroup: String? {
        switch kind {
        case .input: "chlink"
        case .auxIn: "auxlink"
        case .fxReturn: "fxlink"
        case .bus: "buslink"
        case .mainStereo, .mainMono, .dca: nil
        }
    }
}

/// The desk-wide Link Preferences (Setup > config, doc p.20): which parts of a linked pair move together.
/// Declared in the desk's order, which the link alert lists them in.
public enum LinkSection: String, CaseIterable, Sendable {
    case gainDelay = "hadly"
    case eq
    case dynamics = "dyn"
    case faderMute = "fdrmute"

    public var preferenceAddress: String { "/config/linkcfg/" + rawValue }

    /// The preference governing a strip parameter, by the part after the strip prefix; nil means never shared.
    /// Pan stays per side (seen on the desk). Sends follow the fader and the low cut follows the EQ: both are
    /// assumptions until m32-probe section 7 answers them.
    public static func of(suffix: String) -> LinkSection? {
        if suffix == "/mix/pan" { return nil }
        if suffix.hasPrefix("/mix/") { return .faderMute }
        if suffix.hasPrefix("/eq/") || suffix.hasPrefix("/preamp/hp") { return .eq }
        if suffix.hasPrefix("/preamp/") { return .gainDelay }
        if suffix.hasPrefix("/gate/") || suffix.hasPrefix("/dyn/") { return .dynamics }
        return nil
    }
}

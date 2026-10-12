import Foundation

/// The preamps (headamps 0-127: local, then AES50 A and B) and which strip each one feeds (doc p.43).
extension Catalog {
    public static func headampGain(_ index: Int) -> ParamSpec {
        ParamSpec(
            headamp(index) + "/gain", CoreStrings.text("Gain"), .linear(min: -12, max: 60, step: 0.5),
            .decibels, reset: 0)
    }

    public static func headampPhantom(_ index: Int) -> ParamSpec {
        ParamSpec(headamp(index) + "/phantom", CoreStrings.text("48V"), .toggle, .plain)
    }

    /// The console answers which headamp (0-127) feeds input `n`, or -1 for internal sources (doc p.43).
    public static func headampIndex(forInput n: Int) -> String {
        "/-ha/" + String(format: "%02d", n - 1) + "/index"
    }

    /// The same for any strip: 32-39 are aux 1-8 (doc p.43); FX returns, buses and the rest have no preamp.
    public static func headampIndex(_ strip: StripID) -> String? {
        switch strip.kind {
        case .input: headampIndex(forInput: strip.number)
        case .auxIn: headampIndex(forInput: 32 + strip.number)
        default: nil
        }
    }

    /// The strips a headamp can feed: inputs, and aux ins routed from an input (`/config/routing/IN/AUX`, doc p.21).
    public static let preampStrips = [StripKind.input, .auxIn].flatMap(StripID.all)

    public static let headampIndexAddresses = preampStrips.compactMap(headampIndex)

    static func headampAddresses() -> [String] {
        (0..<128).flatMap { [headampGain($0).address, headampPhantom($0).address] }
    }

    private static func headamp(_ index: Int) -> String {
        "/headamp/" + String(format: "%03d", index)
    }
}

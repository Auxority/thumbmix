import Foundation

/// An EQ band's filter type; the raw value is the desk's type number (doc p.33). Inputs, aux ins, FX returns and buses
/// offer the first six, mains and matrices all of them.
public enum EQFilterType: Int, CaseIterable, Sendable {
    case lowCut, lowShelf, parametric, vintage, highShelf, highCut
    case butterworth6, butterworth12, bessel12, linkwitzRiley12, butterworth18, butterworth24, bessel24, linkwitzRiley24

    public static let ofInputs = Array(allCases.prefix(6))

    /// The desk's own abbreviation, which the protocol's choice names use.
    public var deskName: String {
        switch self {
        case .lowCut: "LCut"
        case .lowShelf: "LShv"
        case .parametric: "PEQ"
        case .vintage: "VEQ"
        case .highShelf: "HShv"
        case .highCut: "HCut"
        case .butterworth6: "BU6"
        case .butterworth12: "BU12"
        case .bessel12: "BS12"
        case .linkwitzRiley12: "LR12"
        case .butterworth18: "BU18"
        case .butterworth24: "BU24"
        case .bessel24: "BS24"
        case .linkwitzRiley24: "LR24"
        }
    }

    /// The M32 manual's own names for the modes ("Equaliser"): VEQ is "a bell filter that provides a more
    /// 'Vintage EQ' sound". The manual doesn't list the crossovers; their names follow `Crossover`.
    public var name: String {
        switch self {
        case .lowCut: CoreStrings.text("Low cut")
        case .lowShelf: CoreStrings.text("Low shelf")
        case .parametric: CoreStrings.text("Parametric EQ")
        case .vintage: CoreStrings.text("Vintage EQ")
        case .highShelf: CoreStrings.text("High shelf")
        case .highCut: CoreStrings.text("High cut")
        case .butterworth6: CoreStrings.text("Butterworth 6 dB/oct")
        case .butterworth12: CoreStrings.text("Butterworth 12 dB/oct")
        case .bessel12: CoreStrings.text("Bessel 12 dB/oct")
        case .linkwitzRiley12: CoreStrings.text("Linkwitz-Riley 12 dB/oct")
        case .butterworth18: CoreStrings.text("Butterworth 18 dB/oct")
        case .butterworth24: CoreStrings.text("Butterworth 24 dB/oct")
        case .bessel24: CoreStrings.text("Bessel 24 dB/oct")
        case .linkwitzRiley24: CoreStrings.text("Linkwitz-Riley 24 dB/oct")
        }
    }

    /// Cut filters (LCut, HCut, the mains' crossovers) have no level to shape, so Gain and Q do nothing there.
    /// The doc lists gain and Q for every type without saying so: assumed, to check on the desk (TODO).
    public var shapesLevel: Bool {
        switch self {
        case .lowShelf, .parametric, .vintage, .highShelf: true
        default: false
        }
    }

    /// BU6…LR24, which only a main or matrix EQ's outer bands take.
    public var isCrossover: Bool { rawValue >= EQFilterType.butterworth6.rawValue }
}

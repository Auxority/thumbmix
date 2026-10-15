/// The overview's filter chips. Matrix comes last, after the buses and mains that feed it: on a 375 pt screen the
/// last chip needs a swipe, and Main is used far more during a show.
public enum StripGroup: String, CaseIterable, Identifiable, Sendable {
    case inputs = "Inputs"
    case aux = "Aux"
    case fx = "FX"
    case buses = "Buses"
    case dca = "DCA"
    case main = "Main"
    case matrix = "Matrix"

    public var id: Self { self }

    /// The raw value is the catalog key and the English title.
    public var title: String { CoreStrings.text(String.LocalizationValue(rawValue)) }

    public var strips: [StripID] {
        switch self {
        case .inputs: StripID.all(.input)
        case .aux: StripID.all(.auxIn)
        case .fx: StripID.all(.fxReturn)
        case .buses: StripID.all(.bus)
        case .matrix: StripID.all(.matrix)
        case .dca: StripID.all(.dca)
        case .main: [StripID(.mainStereo), StripID(.mainMono)]
        }
    }
}

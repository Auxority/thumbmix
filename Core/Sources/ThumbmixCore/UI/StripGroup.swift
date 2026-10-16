/// The overview's group pills. Matrix comes last, after the buses and mains that feed it.
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

    /// The name on the overview's pill: short, so all seven share a 375 pt screen without scrolling. The desk
    /// prints BUS and MTX on its own buttons.
    public var shortTitle: String {
        switch self {
        case .inputs: CoreStrings.text("In")
        case .buses: CoreStrings.text("Bus")
        case .matrix: CoreStrings.text("Mtx")
        case .aux, .fx, .dca, .main: title
        }
    }

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

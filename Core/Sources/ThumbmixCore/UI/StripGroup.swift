/// The overview's filter chips.
public enum StripGroup: String, CaseIterable, Identifiable, Sendable {
    case inputs = "Inputs", aux = "Aux", fx = "FX", buses = "Buses", dca = "DCA", main = "Main"

    public var id: Self { self }

    public var strips: [StripID] {
        switch self {
        case .inputs: StripID.all(.input)
        case .aux: StripID.all(.auxIn)
        case .fx: StripID.all(.fxReturn)
        case .buses: StripID.all(.bus)
        case .dca: StripID.all(.dca)
        case .main: [StripID(.mainStereo), StripID(.mainMono)]
        }
    }
}

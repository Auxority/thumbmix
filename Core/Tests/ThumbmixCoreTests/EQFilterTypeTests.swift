import Testing

@testable import ThumbmixCore

struct EQFilterTypeTests {
    /// The desk's type numbers are the wire values: 0 is LCut and 2 is PEQ for every EQ, 6...13 the mains' crossovers.
    @Test func rawValuesAreTheDesksTypeNumbers() {
        #expect(
            EQFilterType.allCases.map(\.deskName) == [
                "LCut", "LShv", "PEQ", "VEQ", "HShv", "HCut", "BU6", "BU12", "BS12", "LR12", "BU18", "BU24", "BS24",
                "LR24",
            ])
        #expect(EQFilterType.parametric.rawValue == 2)
        #expect(EQFilterType.allCases.filter(\.isCrossover).map(\.rawValue) == Array(6...13))
    }

    @Test func onlyShelvesAndBellsShapeLevel() {
        #expect(EQFilterType.allCases.filter(\.shapesLevel).map(\.deskName) == ["LShv", "PEQ", "VEQ", "HShv"])
    }

    /// The desk shows no Q for a shelf (2026-10-22), so only the bells keep a Q row.
    @Test func onlyBellsHaveAQ() {
        #expect(EQFilterType.allCases.filter(\.hasQ).map(\.deskName) == ["PEQ", "VEQ"])
    }

    @Test func aTypeNumberTheDeskDoesNotHaveIsNoType() {
        #expect(EQBandState(typeIndex: 14, frequency: 1000, gain: 0, q: 1).type == nil)
    }
}

import Testing

@testable import ThumbmixCore

/// Matrix 1-6 (doc p.33): fed by the buses and both mains, mixed like a bus, linkable in odd/even pairs.
struct MatrixTests {
    private let matrix = StripID(.matrix, 3)

    @Test func addressesFollowTheDoc() {
        #expect(StripID.all(.matrix).count == 6)
        #expect(matrix.prefix == "/mtx/03")
        #expect(matrix.fader == "/mtx/03/mix/fader")
        #expect(matrix.on == "/mtx/03/mix/on")
        #expect(matrix.pan == nil, "the doc lists no pan for a matrix")
        #expect(matrix.defaultName == "Matrix 3")
    }

    @Test func sixBandEQWithTheMainsTypesAndDynamics() {
        #expect(matrix.eqBandCount == 6)
        #expect(matrix.hasDynamics)
        #expect(!matrix.hasGate)
        guard case .choice(let types) = Catalog.eqBand(matrix, 1).type.scale else {
            Issue.record("EQ type must be a choice")
            return
        }
        #expect(types.count == 14)
    }

    @Test func linksInOddEvenPairs() {
        #expect(StripID(.matrix, 6).linkAddress == "/config/mtxlink/5-6")
        #expect(StripID(.matrix, 1).partner == StripID(.matrix, 2))
        #expect(StripID(.matrix, 2).pairDefaultName == "Matrix 1-2")
        #expect(StripID.linkable(from: "/mtx/04/eq/2/g")?.strip == StripID(.matrix, 4))
        #expect(Catalog.linkAddresses.contains("/config/mtxlink/3-4"))
    }

    @Test func busesAndMainsSendToMatrices() {
        #expect(StripKind.bus.sendTarget == .matrix)
        #expect(StripKind.mainStereo.sendTarget == .matrix)
        #expect(StripKind.input.sendTarget == .bus)
        #expect(StripKind.matrix.sendTarget == nil)
        #expect(StripKind.matrix.feeders == [.bus, .mainStereo, .mainMono])
        #expect(StripKind.bus.feeders == [.input, .auxIn, .fxReturn])
        #expect(Catalog.sendLevel(from: StripID(.bus, 12), to: matrix).address == "/bus/12/mix/03/level")
        #expect(Catalog.sendOn(from: StripID(.mainMono), to: matrix).address == "/main/m/mix/03/on")
        #expect(Catalog.sendLevel(from: StripID(.mainStereo), to: matrix).label == "Matrix 3")
    }

    @Test func matrixStateAndItsSendsAreSynced() {
        let addresses = Set(Catalog.syncAddresses())
        for address in ["/mtx/06/mix/fader", "/mtx/01/dyn/thr", "/mtx/02/eq/6/type", "/main/st/mix/06/level"] {
            #expect(addresses.contains(address), "missing \(address)")
        }
    }

    @Test func metersSitBetweenTheBusesAndTheMains() {
        let values = (0..<49).map { Float($0) }
        let readings = MeterBanks.readings(address: "/meters/2", values: values)
        #expect(readings[StripID(.matrix, 1)] == MeterReading(level: 16, dynamicsGain: 41))
        #expect(readings[StripID(.matrix, 6)] == MeterReading(level: 21, dynamicsGain: 46))
    }

    @Test func rtaSourceFollowsTheDoc() {
        #expect(StripID(.matrix, 1).rtaSource == 66)
        #expect(StripID(.matrix, 6).rtaSource == 71)
    }

    @Test func demoDeskFeedsAFillFromTheMains() {
        let state = DemoState.values()
        let fill = StripID(.matrix, 1)
        #expect(state[fill.name] == .string("Fill"))
        #expect(state[Catalog.sendLevel(from: StripID(.mainStereo), to: fill).address] == .float(0.75))
    }

    @Test func screenAndChip() {
        #expect(ChannelTab.tabs(for: .matrix) == [.mix, .eq, .comp, .fedBy])
        #expect(StripGroup.matrix.strips == StripID.all(.matrix))
        #expect(StripGroup.matrix.title == "Matrix")
    }
}

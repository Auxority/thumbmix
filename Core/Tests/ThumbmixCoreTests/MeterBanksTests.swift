import Testing

@testable import ThumbmixCore

struct MeterBanksTests {
    @Test func bankOneHasLevelGateAndDynamicsPerInput() {
        let values = (0..<96).map { Float($0) / 100 }
        let readings = MeterBanks.readings(address: "/meters/1", values: values)
        #expect(
            readings[StripID(.input, 1)] == MeterReading(level: 0, gateGain: 0.32, dynamicsGain: 0.64))
        #expect(
            readings[StripID(.input, 32)] == MeterReading(level: 0.31, gateGain: 0.63, dynamicsGain: 0.95)
        )
    }

    @Test func bankTwoTakesLouderMainSide() {
        var values = [Float](repeating: 0, count: 49)
        values[22] = 0.2
        values[23] = 0.4
        values[47] = 0.9
        #expect(
            MeterBanks.readings(address: "/meters/2", values: values)[StripID(.mainStereo)]
                == MeterReading(level: 0.4, dynamicsGain: 0.9))
    }

    @Test func dcaMetersSitAfterSixteenChannels() {
        let values = (0..<27).map { Float($0) }
        #expect(
            MeterBanks.readings(address: "/meters/5", values: values)[StripID(.dca, 1)]
                == MeterReading(level: 16))
    }

    @Test func shortOrUnknownBanksYieldNothing() {
        #expect(MeterBanks.readings(address: "/meters/1", values: [1, 2]).isEmpty)
        #expect(
            MeterBanks.readings(address: "/meters/9", values: Array(repeating: 1, count: 32)).isEmpty)
    }
}

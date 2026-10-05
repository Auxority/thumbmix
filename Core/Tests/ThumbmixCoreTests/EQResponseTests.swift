import Testing

@testable import ThumbmixCore

struct EQResponseTests {
    @Test func peakingBandHitsItsGainAtCentre() {
        let band = EQBandState(typeIndex: 2, frequency: 1000, gain: 6, q: 2)
        #expect(abs(EQResponse.decibels(at: 1000, bands: [band]) - 6) < 0.05)
        #expect(abs(EQResponse.decibels(at: 20, bands: [band])) < 0.1)
    }

    @Test func lowCutRemovesLows() {
        let band = EQBandState(typeIndex: 0, frequency: 100, gain: 0, q: 1)
        #expect(EQResponse.decibels(at: 20, bands: [band]) < -20)
        #expect(abs(EQResponse.decibels(at: 10_000, bands: [band])) < 0.1)
    }

    @Test func highShelfLiftsHighs() {
        let band = EQBandState(typeIndex: 4, frequency: 1000, gain: 6, q: 0.7)
        #expect(abs(EQResponse.decibels(at: 15_000, bands: [band]) - 6) < 0.5)
    }

    @Test func crossoverTypesDrawFlat() {
        #expect(
            EQResponse.decibels(
                at: 1000, bands: [EQBandState(typeIndex: 9, frequency: 1000, gain: 6, q: 2)]) == 0)
    }

    @Test func bandsAdd() {
        let a = EQBandState(typeIndex: 2, frequency: 1000, gain: 3, q: 2)
        #expect(abs(EQResponse.decibels(at: 1000, bands: [a, a]) - 6) < 0.05)
    }

    @Test @MainActor func mirrorBandsAreEmptyWhenEQIsOff() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        let strip = StripID(.input, 1)
        mirror.apply(OSCMessage(Catalog.eqOn(strip).address, [.int(0)]))
        #expect(mirror.eqBands(strip).isEmpty)
        mirror.apply(OSCMessage(Catalog.eqOn(strip).address, [.int(1)]))
        #expect(mirror.eqBands(strip).count == 4)
    }
}

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

    /// A main's six bands, flat, with `changes` swapped in by band number (1...6).
    private func mainBands(_ changes: [Int: EQBandState]) -> [EQBandState] {
        (1...6).map { changes[$0] ?? EQBandState(typeIndex: 2, frequency: 1000, gain: 0, q: 2) }
    }

    private func crossover(_ type: String, at frequency: Double) -> EQBandState {
        EQBandState(typeIndex: Catalog.mainEQTypes.firstIndex(of: type)!, frequency: frequency, gain: 6, q: 2)
    }

    @Test func crossoverOnBandOneIsAHighPass() {
        let bands = mainBands([1: crossover("BU24", at: 100)])
        #expect(abs(EQResponse.decibels(at: 100, bands: bands) + 3) < 0.1)
        #expect(EQResponse.decibels(at: 20, bands: bands) < -50)
        #expect(abs(EQResponse.decibels(at: 10_000, bands: bands)) < 0.1)
    }

    @Test func crossoverOnBandSixIsALowPass() {
        let bands = mainBands([6: crossover("LR24", at: 1000)])
        #expect(abs(EQResponse.decibels(at: 1000, bands: bands) + 6) < 0.1)
        #expect(EQResponse.decibels(at: 4000, bands: bands) < -40)
        #expect(abs(EQResponse.decibels(at: 50, bands: bands)) < 0.1)
    }

    @Test(arguments: [("BU6", 20.0), ("BU12", 40), ("BU18", 60), ("BU24", 80), ("LR12", 40), ("LR24", 80)])
    func crossoverSlopeIsSixDecibelsPerOctavePerStep(type: String, decadeDrop: Double) {
        let bands = mainBands([6: crossover(type, at: 1000)])
        #expect(abs(EQResponse.decibels(at: 10_000, bands: bands) + decadeDrop) < 1)
    }

    @Test(arguments: ["BS12", "BS24"])
    func besselIsMinusThreeAtCutoffAndGentlerThanButterworth(type: String) {
        let bands = mainBands([6: crossover(type, at: 1000)])
        let butterworth = mainBands([6: crossover(type == "BS12" ? "BU12" : "BU24", at: 1000)])
        #expect(abs(EQResponse.decibels(at: 1000, bands: bands) + 3) < 0.1)
        #expect(EQResponse.decibels(at: 2000, bands: bands) > EQResponse.decibels(at: 2000, bands: butterworth))
    }

    @Test func crossoverSilencesTheBandNextToIt() {
        let boost = EQBandState(typeIndex: 2, frequency: 1000, gain: 6, q: 2)
        let low = mainBands([1: crossover("BU12", at: 20), 2: boost])
        let high = mainBands([6: crossover("BU12", at: 20_000), 5: boost])
        #expect(abs(EQResponse.decibels(at: 1000, bands: low)) < 0.1)
        #expect(abs(EQResponse.decibels(at: 1000, bands: high)) < 0.1)
        #expect(abs(EQResponse.decibels(at: 1000, bands: mainBands([2: boost])) - 6) < 0.05)
    }

    @Test func crossoverOnAMiddleBandDrawsFlat() {
        #expect(EQResponse.decibels(at: 1000, bands: mainBands([3: crossover("LR12", at: 1000)])) == 0)
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

    /// The graph draws the bands as set even while the EQ is off (dashed), so it shows what EQ On brings back.
    @Test @MainActor func bandsAsSetStayWhileEQIsOff() {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))
        let strip = StripID(.input, 1)
        #expect(!mirror.isEQOn(strip), "unread is not on")
        mirror.apply(OSCMessage(Catalog.eqOn(strip).address, [.int(0)]))
        #expect(!mirror.isEQOn(strip))
        #expect(mirror.eqBandsAsSet(strip).count == 4)
        mirror.apply(OSCMessage(Catalog.eqOn(strip).address, [.int(1)]))
        #expect(mirror.isEQOn(strip))
        #expect(mirror.eqBandsAsSet(strip) == mirror.eqBands(strip))
    }
}

import Testing

@testable import ThumbmixCore

struct PresetSummaryTests {
    private func rows(_ part: PresetPart, _ preset: Preset = .kick) -> [String: String] {
        Dictionary(
            PresetSummary.rows(preset, part, locale: .testEnglish).map { ($0.label, $0.value) },
            uniquingKeysWith: { first, _ in first })
    }

    @Test func aGateReadsAsLabelsAndValues() {
        let gate = rows(.gate)
        #expect(gate["Threshold"] == "−40.0 dB")
        #expect(gate["Mode"] == "Gate")
        #expect(gate["Key filter"] == "LC12 · 101.4 Hz")
    }

    @Test func aCompShowsItsRatioAsOneToAndItsPosition() {
        let comp = rows(.comp)
        #expect(comp["Ratio"] == "4.0:1")
        #expect(comp["Comp position"] == "After EQ")
        #expect(comp["Detector"] == "Peak level")
    }

    @Test func theEQListsTheLowCutAndOnlyBandsThatDoSomething() {
        let eq = rows(.eq)
        #expect(eq["Low cut"] == "35.3 Hz")
        #expect(eq["Band 1"]?.hasPrefix("PEQ") == true)
        #expect(eq["Band 4"] == nil, "the flat high shelf is left out")
    }

    @Test func aSwitchedOffLowCutReadsOff() {
        var preset = Preset.kick
        preset.eq?.lowCut?.on = false
        #expect(rows(.eq, preset)["Low cut"] == "Off")
    }

    @Test func theInputShowsPolarityInWords() {
        #expect(rows(.input)["Polarity"] == "Normal")
    }

    @Test func aSendReadsLevelSwitchAndTap() {
        let sends = rows(.sends)
        #expect(sends["Bus 3"] == "−6.0 dB · On · After fader")
        #expect(sends["Bus 4"] == "−∞ dB · Off")
    }

    @Test func theCurveFollowsTheBandsAndTheLowCut() throws {
        let curve = try #require(PresetSummary.eqCurve(.kick))
        #expect(curve.bands.count == 4)
        #expect(curve.lowCut == LowCutState(frequency: 35))
        let boost = EQReading.decibels(at: 100, bands: curve.bands, lowCut: curve.lowCut)
        let flat = EQReading.decibels(at: 1000, bands: [], lowCut: nil)
        #expect(boost > flat + 1, "the 100 Hz bell lifts the curve")
    }

    @Test func aPresetWithoutEQHasNoCurve() {
        var preset = Preset.kick
        preset.eq = nil
        #expect(PresetSummary.eqCurve(preset) == nil)
    }
}

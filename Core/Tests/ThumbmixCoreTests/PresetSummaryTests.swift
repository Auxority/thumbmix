import Testing

@testable import ThumbmixCore

struct PresetSummaryTests {
    private func rows(_ part: PresetPart, _ preset: Preset = .kick) -> [String: String] {
        Dictionary(
            PresetSummary.rows(preset, part, locale: .testEnglish).map { ($0.label, $0.value) },
            uniquingKeysWith: { first, _ in first })
    }

    @Test func aGateReadsAsTheGateTabNamesItsControls() {
        let gate = rows(.gate)
        #expect(gate["Threshold"] == "−40.0 dB")
        #expect(gate["Mode"] == "Gate")
        #expect(gate["Key filter"] == "On · Low cut, 12 dB/oct · 101.4 Hz", "one row for the filter")
    }

    @Test func aCompShowsItsRatioAsOneToAndItsPosition() {
        let comp = rows(.comp)
        #expect(comp["Ratio"] == "4.0:1")
        #expect(comp["Comp position"] == "After EQ")
        #expect(comp["Detector"] == "Peak level")
    }

    @Test func eachEQBandAndTheLowCutIsOneRow() {
        let eq = rows(.eq)
        #expect(eq["Low cut"] == "On · 35.3 Hz")
        #expect(eq["Band 1"] == "Parametric EQ · 101.4 Hz · +3.0 dB · Q 2.0", "a bare number says what it is")
        #expect(eq["Band 4"]?.hasPrefix("High shelf") == true)
        #expect(PresetSummary.rows(.kick, .eq, locale: .testEnglish).count == 6, "EQ, low cut and 4 bands")
    }

    @Test func aSwitchedOffLowCutReadsOff() {
        var preset = Preset.kick
        preset.values[.eq]?["preamp/hpon"] = .flag(false)
        #expect(rows(.eq, preset)["Low cut"]?.hasPrefix("Off") == true)
    }

    @Test func theInputShowsPolarityInWords() {
        #expect(rows(.input)["Polarity"] == "Normal")
    }

    @Test func aSendReadsLevelSwitchAndTap() {
        let sends = rows(.sends)
        #expect(sends["Bus 3"] == "−6.0 dB · On · POST")
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

    @Test func aPresetWithoutEQOrWithAPartialOneHasNoCurve() {
        var preset = Preset.kick
        preset.values[.eq]?["eq/2/f"] = nil
        #expect(PresetSummary.eqCurve(preset) == nil, "a hand-written EQ may leave a band out")
        preset.values[.eq] = nil
        #expect(PresetSummary.eqCurve(preset) == nil)
    }
}

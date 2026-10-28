import Testing

@testable import ThumbmixCore

struct PresetSummaryTests {
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

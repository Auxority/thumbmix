import Foundation
import Testing

@testable import ThumbmixCore

/// The preset page as approved on 2026-10-28 (rounds 4 and 5): compact numbers, a few lines per part, every value in a
/// group, and the EQ as a table of bands in the desk's own type names.
struct PresetGlanceTests {
    private static let dutch = Locale(identifier: "nl_NL")
    private let strip = StripID(.input, 1)

    private func parts(_ value: Double, _ spec: ParamSpec, _ locale: Locale = .testEnglish) -> String {
        ValueText.parts(spec.scale.normalized(forValue: value), spec, locale: locale).text
    }

    private func lines(_ part: PresetPart, _ preset: Preset = .kick) -> [String] {
        PresetSummary.overview(preset, part, locale: .testEnglish).map { "\($0.label)=\($0.value)" }
    }

    // MARK: Compact numbers

    @Test func compactNumbersDropTrailingZeros() {
        let threshold = Catalog.dynamics(strip).threshold
        #expect(parts(-18, threshold) == "−18 dB")
        #expect(parts(-18.5, threshold) == "−18.5 dB")
        #expect(parts(0, Catalog.trim(strip)) == "0 dB", "no sign and no decimals at zero")
        #expect(parts(2.5, Catalog.eqBand(strip, 1).gain) == "+2.5 dB")
        #expect(parts(15, Catalog.gate(strip).attack) == "15 ms")
        #expect(parts(-18.5, threshold, Self.dutch) == "−18,5 dB")
    }

    @Test func frequenciesKeepTheDesksKilohertzTextWithoutTrailingZeros() {
        let hertz = ParamSpec("/test/f", "Freq", .linear(min: 0, max: 20_000, step: 0.1), .hertz)
        #expect(parts(35, hertz) == "35 Hz")
        #expect(parts(124.7, hertz) == "124.7 Hz")
        #expect(parts(3000, hertz) == "3 kHz")
        #expect(parts(1250, hertz) == "1.25 kHz")
        #expect(parts(10_020, hertz) == "10.02 kHz")
        #expect(parts(1250, hertz, Self.dutch) == "1,25 kHz")
    }

    @Test func aValueSplitsIntoItsNumberAndItsUnit() {
        let release = Catalog.gate(strip).release
        let split = ValueText.parts(release.scale.normalized(forValue: 150), release, locale: .testEnglish)
        #expect(split.unit == "ms")
        #expect(split.text == split.number + " ms")
        let mix = Catalog.dynamics(strip).mix
        #expect(ValueText.parts(1, mix, locale: .testEnglish) == ValueParts(number: "100", unit: "%"))
    }

    @Test func aRatioReadsAsALocalizedNumberToOne() {
        let ratio = Catalog.dynamics(strip).ratio
        let index = { (name: String) in Double(Catalog.ratios.firstIndex(of: name)!) }
        #expect(parts(index("4.0"), ratio) == "4:1")
        #expect(parts(index("1.1"), ratio) == "1.1:1")
        #expect(parts(index("1.1"), ratio, Self.dutch) == "1,1:1")
    }

    // MARK: Overview

    @Test func theInputShowsItsFiveValues() {
        #expect(lines(.input) == ["Gain=+30 dB", "48V=Off", "Trim=0 dB", "Polarity=Normal", "Delay=2.5 ms"])
    }

    @Test func theEQShowsTheLowCutAndOnlyTheBandsInUse() throws {
        let eq = PresetSummary.overview(.kick, .eq, locale: .testEnglish)
        #expect(eq.first?.label == "Low cut")
        #expect(eq.first?.value == "35.3 Hz")
        #expect(eq.dropFirst().map(\.value) == ["+3 dB", "−4 dB", "+2 dB"], "band 4 sits at 0 dB")
        #expect(eq[1].label == "101.4 Hz", "a band is named by its frequency")
    }

    @Test func aPartSwitchedOffSaysSoFirst() {
        var preset = Preset.kick
        preset.values[.eq]?["eq/on"] = .flag(false)
        preset.values[.eq]?["preamp/hpon"] = .flag(false)
        let eq = lines(.eq, preset)
        #expect(eq.prefix(2) == ["EQ=Off", "Low cut=Off"])
    }

    @Test func aCutBandShowsItsTypeInsteadOfAGain() {
        var preset = Preset.kick
        preset.values[.eq]?["eq/4/type"] = .option("HCut")
        #expect(PresetSummary.overview(preset, .eq, locale: .testEnglish).last?.value == "HCut")
    }

    @Test func theGateShowsThresholdRangeReleaseAndItsKeyFilter() {
        let gate = lines(.gate)
        #expect(gate.count == 4)
        #expect(gate[0] == "Threshold=−40 dB")
        #expect(gate[1] == "Range=30 dB")
        #expect(gate[2].hasPrefix("Release="))
        #expect(gate[3] == "Key filter=101.4 Hz LC12")
    }

    @Test func theCompShowsRatioThresholdMakeupAndRelease() {
        let comp = lines(.comp)
        #expect(comp.prefix(3) == ["Ratio=4:1", "Threshold=−18 dB", "Makeup=3 dB"])
        #expect(comp[3].hasPrefix("Release="))
        #expect(comp.count == 4)
    }

    @Test func theMixShowsFaderAndPan() {
        #expect(lines(.mix) == ["Fader=−∞ dB", "Pan=C"])
    }

    /// The card's picture: where the fader sits on its throw (the desk's law, 0 dB at three quarters) and the pan.
    @Test func theMixPictureIsTheFadersThrowAndThePan() throws {
        var preset = Preset.kick
        preset.values[.mix]?["mix/fader"] = .number(0)
        preset.values[.mix]?["mix/pan"] = .number(20)

        let mix = try #require(PresetSummary.mixPosition(preset))

        #expect(abs(mix.fader - 0.75) < 0.01)
        #expect(abs(mix.pan - 0.2) < 0.01)
        #expect(PresetSummary.mixPosition(.kick)?.fader == 0, "−∞ at the bottom")
        preset.values[.mix] = nil
        #expect(PresetSummary.mixPosition(preset) == nil)
    }

    @Test func sendsListTheBusesThatAreOnByNumberForTheDesksName() throws {
        let sends = PresetSummary.overview(.kick, .sends, locale: .testEnglish)
        #expect(sends.map { "\($0.label)=\($0.value)" } == ["Bus 3=−6 dB", "Other buses=Off"])
        #expect(sends[0].bus == StripID(.bus, 3), "the app adds the name the desk gives bus 3 now")
        #expect(sends[1].bus == nil)
    }

    /// Switched on at −∞ sends nothing: the desk's default for every send, so listing it would fill the card with noise.
    @Test func aSendAtMinusInfinitySendsNothingAndIsNotListed() {
        var preset = Preset.kick
        preset.values[.sends]?["mix/05/on"] = .flag(true)
        preset.values[.sends]?["mix/05/level"] = .number(-.infinity)
        #expect(lines(.sends, preset) == ["Bus 3=−6 dB", "Other buses=Off"])
    }

    @Test func aSendShowsItsTapOnlyWhenItIsNotAfterTheFader() {
        var preset = Preset.kick
        preset.values[.sends]?["mix/03/type"] = .option("PRE")
        #expect(lines(.sends, preset).first == "Bus 3=−6 dB · Pre-fader")
    }

    @Test func beyondThreeSendsTheRestIsCounted() {
        var preset = Preset.kick
        for bus in 5...9 {
            let key = String(format: "mix/%02d/", bus)
            preset.values[.sends]?[key + "level"] = .number(-10)
            preset.values[.sends]?[key + "on"] = .flag(true)
        }
        let sends = lines(.sends, preset)
        #expect(sends.count == 4)
        #expect(sends.prefix(3).map { $0.components(separatedBy: "=")[0] } == ["Bus 3", "Bus 5", "Bus 6"])
        #expect(sends.last == "Other buses=3 on")
    }

    // MARK: All values

    @Test func theCompGroupsAsApproved() {
        let groups = PresetSummary.groups(.kick, .comp, locale: .testEnglish)
        #expect(groups.map(\.title) == ["Level", "Timing", "How it listens"])
        #expect(groups[0].cells.map(\.label) == ["Comp", "Threshold", "Ratio", "Knee", "Makeup"])
        #expect(groups[0].cells[2].number == "4:1")
        #expect(groups[1].cells.map(\.label) == ["Attack", "Hold", "Release", "Mix"])
        #expect(groups[2].cells.map(\.label) == ["Mode", "Detector", "Envelope", "Position", "Auto"])
        #expect(groups[2].cells[3].number == "After EQ")
    }

    @Test func theGateGroupsWithItsKeyFilter() {
        let groups = PresetSummary.groups(.kick, .gate, locale: .testEnglish)
        #expect(groups.map(\.title) == ["Level", "Timing", "Key filter"])
        #expect(groups[2].cells.map(\.label) == ["Filter", "Type", "Freq"])
    }

    @Test func aCellKeepsItsUnitApart() throws {
        let threshold = try #require(PresetSummary.groups(.kick, .comp, locale: .testEnglish)[0].cells.first { $0.label == "Threshold" })
        #expect(threshold.number == "−18")
        #expect(threshold.unit == "dB")
    }

    @Test func theEQBandsUseTheDesksTypeNames() throws {
        let bands = PresetSummary.bands(.kick, locale: .testEnglish)
        #expect(bands.map(\.type) == ["PEQ", "PEQ", "PEQ", "HShv"])
        #expect(bands[0].frequency == ValueParts(number: "101.4", unit: "Hz"))
        #expect(bands[0].gain == ValueParts(number: "+3", unit: "dB"))
        #expect(bands[0].q.number == "2")
        let dutch = PresetSummary.bands(.kick, locale: Self.dutch)
        #expect(dutch[1].q.number == "1,5")
    }

    @Test func theEQsOwnGroupHoldsTheLowCutAndTheSwitch() {
        let groups = PresetSummary.groups(.kick, .eq, locale: .testEnglish)
        #expect(groups.first?.cells.map(\.label) == ["Low cut", "EQ"])
        #expect(groups.first?.cells.first?.number == "35.3")
    }

    @Test func aSendCellIsOnePerBusAndCarriesTheBus() {
        let cells = PresetSummary.groups(.kick, .sends, locale: .testEnglish).flatMap(\.cells)
        #expect(cells.map(\.label) == ["Bus 3", "Bus 4"])
        #expect(cells[0].bus == StripID(.bus, 3))
        #expect(cells[1].number == "Off")
    }

    /// Nothing a preset holds is left off its page: each value lands in exactly one cell or band.
    @Test(arguments: PresetPart.allCases)
    func everyValueIsShownExactlyOnce(_ part: PresetPart) throws {
        var preset = Preset.kick
        preset.values[part]?["made/up"] = .number(1)
        let shown =
            PresetSummary.groups(preset, part, locale: .testEnglish).flatMap(\.cells).flatMap(\.paths)
            + (part == .eq ? PresetSummary.bands(preset, locale: .testEnglish).flatMap(\.paths) : [])
        let held = try #require(preset.values[part]).keys.sorted()
        #expect(shown.sorted() == held)
    }

    /// A bus has six bands, sends to matrices and no low cut: its page leaves nothing out either.
    @MainActor @Test func aBusPresetShowsEveryValueExactlyOnce() async throws {
        let bus = StripID(.bus, 1)
        try await withLiveDesk { _, mirror in
            await readTabs(mirror, bus)
            let parts = Set(PresetPart.allCases.filter { $0.exists(on: bus) })
            let preset = try #require(mirror.capture(bus, parts: parts, name: "Mon", matchWords: []))
            #expect(preset.parts.count == parts.count)
            for part in preset.parts {
                let shown =
                    PresetSummary.groups(preset, part, locale: .testEnglish).flatMap(\.cells).flatMap(\.paths)
                    + (part == .eq ? PresetSummary.bands(preset, locale: .testEnglish).flatMap(\.paths) : [])
                #expect(shown.sorted() == preset.values[part]?.keys.sorted(), "\(part)")
            }
            #expect(PresetSummary.bands(preset, locale: .testEnglish).count == 6)
        }
    }

    /// A hand-written file may switch the delay on without a time: it reads On, never Off.
    @Test func aDelayOnWithoutATimeReadsOn() {
        var preset = Preset.kick
        preset.values[.input]?["delay/time"] = nil
        #expect(lines(.input, preset).last == "Delay=On")
    }

    /// With no send sending, one line says so for every bus, not "Other buses" with nothing before it.
    @Test func noSendSendingReadsAllBusesOff() {
        var preset = Preset.kick
        preset.values[.sends]?["mix/03/on"] = .flag(false)
        #expect(lines(.sends, preset) == ["All buses=Off"])
    }

    @Test func theRepoPresetsReadWithoutAnyLeftOver() throws {
        for name in ["kick", "lead-vocal"] {
            let preset = try PresetValidation.decode(Data(contentsOf: repoPreset(name)))
            for part in preset.parts {
                #expect(!PresetSummary.groups(preset, part, locale: .testEnglish).contains { $0.title == "Other" })
            }
        }
    }

    // MARK: Curves

    @Test func theGateCurveCutsBelowItsThreshold() throws {
        let gate = try #require(PresetSummary.gateCurve(.kick))
        #expect(gate.mode == .gate)
        #expect(gate.threshold == -40)
        #expect(gate.output(-50) == -80, "30 dB down under the threshold")
        #expect(gate.output(-20) == -20)
    }

    @Test func theCompCurveTakesTheRatioOption() throws {
        let comp = try #require(PresetSummary.compCurve(.kick))
        #expect(comp.ratio == 4)
        #expect(comp.makeup == 3)
        #expect(comp.output(-60) == -57, "makeup lifts the quiet part")
        #expect(comp.output(0) < 0 + 3, "4:1 above the threshold")
    }

    @Test func aPresetWithoutTheParthasNoCurve() {
        var preset = Preset.kick
        preset.values[.gate] = nil
        preset.values[.comp]?["dyn/ratio"] = nil
        #expect(PresetSummary.gateCurve(preset) == nil)
        #expect(PresetSummary.compCurve(preset) == nil)
    }

    private func repoPreset(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("presets/\(name).json")
    }
}

import FakeM32
import Testing

@testable import ThumbmixCore

/// What a saved preset holds, and which of its parts fit a strip.
@MainActor
struct PresetSaveTests {
    private let kick = StripID(.input, 1)
    private let snare = StripID(.input, 2)

    // MARK: Saving

    /// The Presets page reads these on opening; the lists of who feeds a strip hold nothing a preset saves.
    @Test func aPresetReadsEveryTabButTheFeedLists() {
        #expect(ChannelTab.presetTabs(for: .input) == [.mix, .input, .gate, .eq, .comp, .sends])
        #expect(ChannelTab.presetTabs(for: .bus) == [.mix, .eq, .comp, .sends])
        #expect(ChannelTab.presetTabs(for: .dca) == [.mix])
    }

    @Test func savingWaitsUntilEveryTickedPartIsRead() async throws {
        try await withLiveDesk { _, mirror in
            let unopened = StripID(.input, 20)
            #expect(!mirror.isReadForPreset(.eq, of: unopened))
            #expect(mirror.capture(unopened, parts: [.eq], name: "x", matchWords: []) == nil)
            await openTab(.eq, of: unopened, in: mirror)
            #expect(mirror.isReadForPreset(.eq, of: unopened))
            #expect(!mirror.isReadForPreset(.gate, of: unopened), "another tab, still unread")
            #expect(mirror.capture(unopened, parts: [.eq], name: "x", matchWords: [])?.holds(.eq) == true)
        }
    }

    @Test func aSavedPresetHoldsTheDesksValuesInRealUnits() async throws {
        try await withDesk([
            (Catalog.gate(kick).threshold, -40), (Catalog.eqBand(kick, 2).frequency, 400), (Catalog.dynamicsPosition(kick)!, 0),
        ]) { _, mirror in
            await readTabs(mirror, kick)
            let preset = try savePreset(kick, mirror)
            #expect(preset[.gate, "gate/thr"] == .number(-40))
            #expect(preset[.eq, "eq/4/type"] != nil && preset[.eq, "eq/5/type"] == nil, "an input has 4 bands")
            guard case .number(let hertz)? = preset[.eq, "eq/2/f"] else {
                Issue.record("no band 2")
                return
            }
            #expect(abs(hertz - 400) < 8, "the nearest step of a log scale")
            #expect(preset[.comp, "dyn/pos"] == .option("PRE"))
            #expect(preset[.gate, "gate/keysrc"] == nil, "the key source names another strip")
            #expect(preset.stripKind == .input)
            #expect(try PresetValidation.decode(PresetJSON.encode(preset)) == preset, "what is saved reads back")
        }
    }

    @Test func partsTheStripLacksAreLeftOut() async throws {
        try await withLiveDesk { _, mirror in
            let aux = StripID(.auxIn, 1)
            await readTabs(mirror, aux)
            let preset = try savePreset(aux, mirror)
            #expect(preset.parts == [.input, .eq, .mix, .sends], "an aux in has no gate or comp")
            #expect(preset[.eq, "preamp/hpon"] == nil, "nor a low cut")
            #expect(preset[.input, "delay/on"] == nil, "nor a delay")
        }
    }

    // MARK: Fit

    @Test func anEQOfAnotherLayoutIsGreyedWithItsReason() async throws {
        try await withLiveDesk { _, mirror in
            let bus = StripID(.bus, 1)
            await readTabs(mirror, kick, bus)
            let preset = try savePreset(kick, mirror)
            #expect(mirror.fit(of: .eq, in: preset, onto: bus) != .fits)
            if case .cannot(let reason) = mirror.fit(of: .eq, in: preset, onto: bus) { #expect(!reason.isEmpty) }
            #expect(mirror.fit(of: .gate, in: preset, onto: bus) != .fits, "buses have no gate")
            #expect(mirror.fit(of: .input, in: preset, onto: bus) != .fits, "buses have no Input tab")
            #expect(mirror.fit(of: .sends, in: preset, onto: bus) != .fits, "an input's sends go to buses")
            #expect(mirror.fit(of: .comp, in: preset, onto: bus) == .fits)
            #expect(mirror.fit(of: .eq, in: preset, onto: snare) == .fits)
        }
    }

    @Test func aMainsEQTypeThatAnInputLacksIsGreyedOnTheInput() async throws {
        try await withLiveDesk { _, mirror in
            let matrix = StripID(.matrix, 1)
            await readTabs(mirror, matrix, StripID(.mainStereo), StripID(.bus, 2))
            var preset = try savePreset(matrix, mirror, parts: [.eq])
            preset.values[.eq]?["eq/1/type"] = .option("BU12")
            #expect(preset.stripKind == .matrix)
            #expect(mirror.fit(of: .eq, in: preset, onto: StripID(.mainStereo)) == .fits, "same 14 types")
            #expect(mirror.fit(of: .eq, in: preset, onto: StripID(.bus, 2)) != .fits, "6 bands, but only 6 types")
        }
    }

    @Test func aPartThePresetLacksIsMarkedAsSuch() async throws {
        try await withLiveDesk { _, mirror in
            await readTabs(mirror, kick)
            let preset = try savePreset(kick, mirror, parts: [.eq])
            #expect(mirror.fit(of: .gate, in: preset, onto: snare) == .notInPreset)
        }
    }

    @Test func aPartStillBeingReadIsGreyedAsReading() async throws {
        try await withLiveDesk { _, mirror in
            await readTabs(mirror, kick)
            let preset = try savePreset(kick, mirror)
            let unopened = StripID(.input, 21)
            #expect(mirror.fit(of: .eq, in: preset, onto: unopened) == .reading)
            await openTab(.eq, of: unopened, in: mirror)
            #expect(mirror.fit(of: .eq, in: preset, onto: unopened) == .fits)
        }
    }
}

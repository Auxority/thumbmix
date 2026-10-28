import FakeM32
import Testing

@testable import ThumbmixCore

/// What a saved preset holds, and which of its parts fit a strip.
@MainActor
struct PresetSaveTests {
    private let kick = StripID(.input, 1)
    private let snare = StripID(.input, 2)

    // MARK: Saving

    @Test func savingWaitsUntilEveryTickedPartIsRead() async throws {
        try await withLiveDesk { _, mirror in
            let unopened = StripID(.input, 20)
            #expect(!mirror.isReadForPreset(.eq, of: unopened))
            #expect(mirror.capture(unopened, parts: [.eq], name: "x", matchWords: []) == nil)
            await openTab(.eq, of: unopened, in: mirror)
            #expect(mirror.isReadForPreset(.eq, of: unopened))
            #expect(!mirror.isReadForPreset(.gate, of: unopened), "another tab, still unread")
            #expect(mirror.capture(unopened, parts: [.eq], name: "x", matchWords: [])?.eq != nil)
        }
    }

    @Test func aSavedPresetHoldsTheDesksValuesInRealUnits() async throws {
        try await withDesk([
            (Catalog.gate(kick).threshold, -40), (Catalog.eqBand(kick, 2).frequency, 400), (Catalog.dynamicsPosition(kick)!, 0),
        ]) { _, mirror in
            await readTabs(mirror, kick)
            let preset = try savePreset(kick, mirror)
            #expect(preset.gate?.thresholdDb == -40)
            #expect(preset.eq?.bands.count == 4)
            #expect(abs((preset.eq?.bands[1].hz ?? 0) - 400) < 8, "the nearest step of a log scale")
            #expect(preset.comp?.position == "PRE")
            #expect(preset.stripKind == .input)
            #expect(try PresetValidation.decode(PresetJSON.encode(preset)) == preset, "what is saved reads back")
        }
    }

    @Test func partsTheStripLacksAreLeftOut() async throws {
        try await withLiveDesk { _, mirror in
            let aux = StripID(.auxIn, 1)
            await readTabs(mirror, aux)
            let preset = try savePreset(aux, mirror)
            #expect(preset.gate == nil)
            #expect(preset.comp == nil)
            #expect(preset.eq?.lowCut == nil)
            #expect(preset.input != nil)
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
            preset.eq?.bands[0].type = "BU12"
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

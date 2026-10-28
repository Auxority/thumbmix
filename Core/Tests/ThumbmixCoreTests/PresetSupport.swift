import FakeM32
import Foundation
import Testing

@testable import ThumbmixCore

extension Preset {
    /// A kick's preset on an input: every part, values inside every range.
    static let kick = Preset(
        name: "Kick",
        matchWords: ["kick", "bass drum"],
        stripKind: .input,
        input: InputPart(
            gainDb: 30, phantom: false, trimDb: 0, polarityFlipped: false, delayOn: true, delayMs: 2.5),
        eq: EQPart(
            on: true,
            lowCut: LowCutPart(on: true, hz: 35),
            bands: [
                BandPart(type: "PEQ", hz: 100, db: 3, q: 2), BandPart(type: "PEQ", hz: 400, db: -4, q: 1.5),
                BandPart(type: "PEQ", hz: 2500, db: 2, q: 2), BandPart(type: "HShv", hz: 10_000, db: 0, q: 2),
            ]),
        gate: GatePart(
            on: true, mode: "GATE", thresholdDb: -40, rangeDb: 30, attackMs: 1, holdMs: 50, releaseMs: 200,
            keyFilter: KeyFilterPart(on: true, type: "LC12", hz: 100)),
        comp: CompPart(
            on: true, mode: "COMP", thresholdDb: -18, ratio: "4.0", knee: 2, attackMs: 10, holdMs: 10,
            releaseMs: 150, makeupDb: 3, mixPercent: 100, detector: "PEAK", envelope: "LOG", auto: false,
            position: "POST", keyFilter: nil),
        mix: MixPart(faderDb: -.infinity, pan: 0),
        sends: [
            "3": SendPart(levelDb: -6, on: true, tap: "POST"),
            "4": SendPart(levelDb: -.infinity, on: false, tap: nil),
        ])
}

/// `Preset.kick` as JSON, changed by `edit`: the way a file with one wrong value is made.
func kickJSON(_ edit: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
    var object = try #require(try JSONSerialization.jsonObject(with: PresetJSON.encode(.kick)) as? [String: Any])
    edit(&object)
    return try JSONSerialization.data(withJSONObject: object)
}

// MARK: A live desk for the save and load tests

/// Reads every tab a preset touches, as the Presets page does on opening.
@MainActor
func readTabs(_ mirror: ConsoleMirror, _ strips: StripID...) async {
    for strip in strips {
        for tab in ChannelTab.presetTabs(for: strip.kind) {
            await openTab(tab, of: strip, in: mirror)
        }
    }
}

func setOnDesk(_ fake: FakeM32, _ spec: ParamSpec, _ value: Double) {
    fake.deskChange(spec.address, spec.scale.argument(fromNormalized: spec.scale.normalized(forValue: value)))
}

/// A live desk whose `settings` (real units) were set before the mirror connected.
@MainActor
func withDesk(_ settings: [(ParamSpec, Double)], body: (FakeM32, ConsoleMirror) async throws -> Void) async throws {
    try await withLiveDesk(
        before: { fake in for (spec, value) in settings { setOnDesk(fake, spec, value) } }, body: body)
}

/// What the console holds, in real units to 3 decimals: the 32-bit float on the wire leaves noise beyond that.
func deskValue(_ fake: FakeM32, _ spec: ParamSpec) -> Double? {
    fake.value(at: spec.address).flatMap(spec.scale.normalized(from:)).map(spec.scale.value(fromNormalized:))
        .map { ($0 * 1000).rounded() / 1000 }
}

@MainActor
func savePreset(
    _ strip: StripID, _ mirror: ConsoleMirror, parts: Set<PresetPart> = Set(PresetPart.allCases)
) throws -> Preset {
    try #require(mirror.capture(strip, parts: parts, name: "Test", matchWords: ["test"]))
}

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
        values: [
            .input: [
                "headamp/gain": .number(30), "headamp/phantom": .flag(false), "preamp/trim": .number(0),
                "preamp/invert": .flag(false), "delay/on": .flag(true), "delay/time": .number(2.5),
            ],
            .eq: [
                "eq/on": .flag(true), "preamp/hpon": .flag(true), "preamp/hpf": .number(35),
                "eq/1/type": .option("PEQ"), "eq/1/f": .number(100), "eq/1/g": .number(3), "eq/1/q": .number(2),
                "eq/2/type": .option("PEQ"), "eq/2/f": .number(400), "eq/2/g": .number(-4), "eq/2/q": .number(1.5),
                "eq/3/type": .option("PEQ"), "eq/3/f": .number(2500), "eq/3/g": .number(2), "eq/3/q": .number(2),
                "eq/4/type": .option("HShv"), "eq/4/f": .number(10_000), "eq/4/g": .number(0), "eq/4/q": .number(2),
            ],
            .gate: [
                "gate/on": .flag(true), "gate/mode": .option("GATE"), "gate/thr": .number(-40),
                "gate/range": .number(30), "gate/attack": .number(1), "gate/hold": .number(50),
                "gate/release": .number(200), "gate/filter/on": .flag(true), "gate/filter/type": .option("LC12"),
                "gate/filter/f": .number(100),
            ],
            .comp: [
                "dyn/on": .flag(true), "dyn/mode": .option("COMP"), "dyn/thr": .number(-18), "dyn/ratio": .option("4.0"),
                "dyn/knee": .number(2), "dyn/attack": .number(10), "dyn/hold": .number(10), "dyn/release": .number(150),
                "dyn/mgain": .number(3), "dyn/mix": .number(100), "dyn/det": .option("PEAK"), "dyn/env": .option("LOG"),
                "dyn/auto": .flag(false), "dyn/pos": .option("POST"),
            ],
            .mix: ["mix/fader": .number(-.infinity), "mix/pan": .number(0)],
            .sends: [
                "mix/03/level": .number(-6), "mix/03/on": .flag(true), "mix/03/type": .option("POST"),
                "mix/04/level": .number(-.infinity), "mix/04/on": .flag(false),
            ],
        ])

    func named(_ name: String) -> Preset {
        var copy = self
        copy.name = name
        return copy
    }

    subscript(_ part: PresetPart, _ path: String) -> PresetValue? { values[part]?[path] }
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

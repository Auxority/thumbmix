import Testing

@testable import ThumbmixCore

/// `DemoState.defaultValue` picks a value by address suffix, first match wins: a new address that an earlier suffix
/// catches silently gets another parameter's value. Every parameter the app reads must get one its scale can hold.
struct DemoStateTests {
    @Test func everyDefaultFitsItsParameter() {
        let read = Set(Catalog.allAddresses())
        let specs = Self.specs().filter { read.contains($0.address) }
        let misfits = specs.filter { !Self.fits(DemoState.defaultValue(for: $0.address), $0.scale) }
        #expect(misfits.map(\.address) == [])
        #expect(specs.count > 4000, "the specs gathered here cover what the app reads")
    }

    /// Values the app's screens and tests lean on, each with why it is that value (typed as the address needs).
    struct Expected: Sendable, CustomTestStringConvertible {
        let address: String
        let value: OSCArgument
        let why: String
        var testDescription: String { "\(address) \(why)" }
        init(_ address: String, _ value: OSCArgument, _ why: String = "") {
            (self.address, self.value, self.why) = (address, value, why)
        }
    }

    static let expected = [
        Expected("/ch/01/delay/on", .int(0), "delay starts off"),
        Expected("/ch/01/preamp/hpon", .int(0), "low cut off, an int"),
        Expected("/ch/01/preamp/hpslope", .int(2), "low cut slope, an int"),
        Expected("/ch/01/preamp/invert", .int(0), "a toggle, not mid-travel"),
        Expected("/-stat/solosw/01", .int(0), "unsoloed"),
        Expected("/ch/01/mix/st", .int(1), "channel starts in the main mix"),
        Expected("/bus/01/mix/st", .int(1), "bus starts in the main mix"),
        Expected("/ch/01/insert/on", .int(0), "an int toggle, off; not the generic /on"),
        Expected("/ch/01/insert/pos", .int(1)),
        Expected("/ch/01/insert/sel", .int(0)),
        Expected("/fx/5/type", .int(4), "Dual DeEsser"),
        Expected("/ch/13/insert/sel", .int(9), "Vox 1 on FX5 L"),
        Expected("/ch/13/insert/on", .int(1)),
        Expected("/ch/08/insert/sel", .int(19), "Bass on Aux out 3"),
        // Mono is off after a desk reset (assumed); the demo's kick and bass feed a mono sub at 0 dB.
        Expected("/ch/01/mix/mono", .int(1)),
        Expected("/ch/08/mix/mono", .int(1)),
        Expected("/ch/01/mix/mlevel", .float(0.75)),
        Expected("/ch/02/mix/mono", .int(0)),
        Expected("/ch/02/mix/mlevel", .float(0)),
        // Every group off, an int switch; the drums in mute group 1, the vocals in group 2.
        Expected("/config/mute/1", .int(0), "an int switch, off; it matches no suffix"),
        Expected("/config/mute/6", .int(0)),
        Expected("/ch/01/grp/mute", .int(0b01), "Kick in mute group 1"),
        Expected("/ch/13/grp/mute", .int(0b10), "Vox 1 in mute group 2"),
        Expected("/ch/08/grp/mute", .int(0), "Bass in none"),
        Expected("/mtx/01/grp/mute", .int(0), "an int mask, not mid-travel"),
    ]

    @Test(arguments: expected) func theDemoStartsWith(_ entry: Expected) {
        #expect(DemoState.values()[entry.address] == entry.value, "\(entry.why)")
    }

    /// The right type, and inside the scale: a choice's index in its list, a float within 0...1.
    private static func fits(_ value: OSCArgument, _ scale: ParamScale) -> Bool {
        guard let position = scale.normalized(from: value) else { return false }
        return (0...1).contains(position)
    }

    private static func specs() -> [ParamSpec] {
        StripKind.allCases.flatMap(StripID.all).flatMap(stripSpecs)
            + (0..<128).flatMap { [Catalog.headampGain($0), Catalog.headampPhantom($0)] }
    }

    private static func stripSpecs(_ strip: StripID) -> [ParamSpec] {
        let optional = [Catalog.pan(strip), Catalog.invert(strip), Catalog.dynamicsPosition(strip)].compactMap { $0 }
        let sections =
            Catalog.gate(strip).all + Catalog.dynamics(strip).all + (Catalog.lowCut(strip)?.all ?? [])
            + (Catalog.delay(strip)?.all ?? []) + (Catalog.insert(strip)?.all ?? [])
        let bands = (0..<strip.eqBandCount).flatMap { Catalog.eqBand(strip, $0 + 1).all }
        let keys = [Catalog.gateKey(strip), Catalog.dynamicsKey(strip)].flatMap {
            [$0.filterOn, $0.filterType, $0.filterFrequency]
        }
        let own = [Catalog.fader(strip), Catalog.on(strip), Catalog.trim(strip), Catalog.eqOn(strip)]
        return own + optional + sections + bands + keys + sendSpecs(strip)
    }

    private static func sendSpecs(_ strip: StripID) -> [ParamSpec] {
        let targets = (strip.kind.sendTarget.map(StripID.all) ?? []) + [StripID(.mainStereo), StripID(.mainMono)]
        return targets.flatMap { target in
            [Catalog.feedOn(from: strip, to: target), Catalog.feedLevel(from: strip, to: target)]
                + [
                    Catalog.sendPan(from: strip, to: target), Catalog.sendPanFollow(from: strip, to: target),
                    Catalog.sendTap(from: strip, to: target),
                ].compactMap { $0 }
        }
    }
}

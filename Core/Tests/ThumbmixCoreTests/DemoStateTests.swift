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

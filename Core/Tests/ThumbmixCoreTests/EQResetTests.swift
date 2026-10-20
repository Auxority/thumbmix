import FakeM32
import Testing

@testable import ThumbmixCore

@MainActor
struct EQResetTests {
    private let kick = StripID(.input, 1)

    /// What the console holds for `spec`, in real units.
    private func deskValue(_ fake: FakeM32, _ spec: ParamSpec) -> Double? {
        fake.value(at: spec.address).flatMap(spec.scale.normalized(from:)).map(spec.scale.value(fromNormalized:))
    }

    private let sixBandStrips = [StripID(.bus, 1), StripID(.matrix, 1), StripID(.mainStereo), StripID(.mainMono)]

    @Test func everyStripWithBandsHasDefaults() {
        let input = Catalog.eqDefaults(kick)
        #expect(input?.map(\.frequency) == [124.7, 496.6, 1977, 10_020])
        #expect(input?.map(\.typeIndex) == [2, 2, 2, 4], "PEQ, PEQ, PEQ, HShv")
        #expect(input?.allSatisfy { $0.gain == 0 && $0.q == 2 } == true)
        for strip in sixBandStrips {
            let defaults = Catalog.eqDefaults(strip)
            #expect(defaults?.map(\.frequency) == [79.6, 158.9, 496.6, 1977, 5020, 10_020], "\(strip)")
            #expect(defaults?.map(\.typeIndex) == [1, 2, 2, 2, 2, 4], "LShv, PEQ × 4, HShv on \(strip)")
            #expect(defaults?.allSatisfy { $0.gain == 0 && $0.q == 2 } == true, "\(strip)")
        }
        #expect(Catalog.eqDefaults(StripID(.auxIn, 1)) == input, "assumed like an input's (TODO)")
        #expect(Catalog.eqDefaults(StripID(.fxReturn, 1)) == input, "assumed like an input's (TODO)")
    }

    /// The desk keeps 201 frequency steps, 3.5% apart: a default must name one step, not fall between two.
    @Test func defaultFrequenciesSitOnTheDesksSteps() {
        for strip in [kick] + sixBandStrips {
            let scale = Catalog.eqBand(strip, 1).frequency.scale
            for band in Catalog.eqDefaults(strip) ?? [] {
                let step = scale.value(fromNormalized: scale.normalized(forValue: band.frequency))
                #expect(abs(step / band.frequency - 1) < 0.003, "\(band.frequency) Hz on \(strip)")
            }
        }
    }

    /// Offline mode opens on the bands Reset bands would give, not every band stacked at mid-travel.
    @Test func theDemoDeskStartsEveryEQAtItsDefaults() {
        let state = DemoState.values()
        func value(_ spec: ParamSpec) -> Double? {
            state[spec.address].flatMap(spec.scale.normalized(from:)).map(spec.scale.value(fromNormalized:))
        }
        for strip in [kick, StripID(.input, 32)] + sixBandStrips {
            for (index, target) in (Catalog.eqDefaults(strip) ?? []).enumerated() {
                let specs = Catalog.eqBand(strip, index + 1)
                #expect(state[specs.type.address] == .int(Int32(target.typeIndex)), "\(specs.type.address)")
                #expect(value(specs.frequency).map { abs($0 / target.frequency - 1) < 0.003 } == true, "\(strip)")
                #expect(value(specs.gain) == target.gain, "\(specs.gain.address)")
                #expect(value(specs.q).map { abs($0 - target.q) < 0.05 } == true, "\(specs.q.address)")
            }
        }
    }

    /// One source of truth: a row's double-tap restores what Reset bands would.
    @Test func bandRowsResetToTheBandsDefault() {
        let band = Catalog.eqBand(StripID(.matrix, 2), 3)
        #expect(band.frequency.resetValue == 496.6)
        #expect(band.q.resetValue == 2)
        #expect(band.gain.resetValue == 0)
        #expect(Catalog.eqBand(kick, 4).frequency.resetValue == 10_020)
    }

    /// Matrices and mains offer 14 types; the defaults use only LShv, PEQ and HShv, at the same index for all.
    @Test func resetBandsOnAMainWritesAHighShelf() async throws {
        try await withLiveDesk { fake, mirror in
            let main = StripID(.mainStereo)
            fake.deskChange("/main/st/eq/6/type", .int(13))
            #expect(await eventually { mirror.cell("/main/st/eq/6/type").argument == .int(13) })

            mirror.resetEQBands(main)

            let specs = Catalog.eqBand(main, 6)
            #expect(await eventually { fake.value(at: specs.type.address) == .int(4) })
            #expect(await eventually { abs((deskValue(fake, specs.frequency) ?? 0) - 10_020) < 10 })
        }
    }

    /// The doc doesn't say which types ignore gain and Q; cut filters have no level to shape (assumed, see TODO).
    @Test func onlyShapingTypesUseGainAndQ() {
        for type in EQFilterType.allCases {
            #expect(type.shapesLevel == ["LShv", "PEQ", "VEQ", "HShv"].contains(type.deskName), "\(type.deskName)")
        }
    }

    /// Main LR's type 7 is BU12, a type inputs don't have: the band's own type list decides.
    @Test func mirrorTellsWhetherABandShapesLevel() async throws {
        try await withLiveDesk { fake, mirror in
            await openTab(.eq, of: kick, in: mirror)
            await openTab(.eq, of: StripID(.mainStereo), in: mirror)
            #expect(mirror.eqBandShapesLevel(kick, 1) == true, "the demo's bands are PEQs")

            fake.deskChange("/ch/01/eq/1/type", .int(0))
            fake.deskChange("/main/st/eq/2/type", .int(7))

            #expect(await eventually { mirror.eqBandShapesLevel(kick, 1) == false })
            #expect(await eventually { mirror.eqBandShapesLevel(StripID(.mainStereo), 2) == false })
            #expect(mirror.eqBandShapesLevel(StripID(.mainStereo), 3) == true)
        }
    }

    @Test func resetBandsPutsEveryBandBackToItsDefault() async throws {
        try await withLiveDesk { fake, mirror in
            fake.deskChange("/ch/01/eq/1/type", .int(0))
            fake.deskChange("/ch/01/eq/3/g", .float(0.9))
            #expect(await eventually { mirror.cell("/ch/01/eq/3/g").argument == .float(0.9) })

            mirror.resetEQBands(kick)

            let expected: [(type: Double, hertz: Double, band: Int)] = [
                (2, 124.7, 1), (2, 496.6, 2), (2, 1977, 3), (4, 10_020, 4),
            ]
            for (type, hertz, band) in expected {
                let specs = Catalog.eqBand(kick, band)
                #expect(
                    await eventually {
                        deskValue(fake, specs.type) == type && deskValue(fake, specs.gain) == 0
                            && abs((deskValue(fake, specs.frequency) ?? 0) - hertz) < hertz * 0.01
                            && abs((deskValue(fake, specs.q) ?? 0) - 2) < 0.05
                    }, "band \(band)")
            }
        }
    }

    @Test func resetOneBandLeavesTheOthers() async throws {
        try await withLiveDesk { fake, mirror in
            fake.deskChange("/ch/01/eq/2/g", .float(0.9))
            fake.deskChange("/ch/01/eq/3/g", .float(0.9))
            #expect(await eventually { mirror.cell("/ch/01/eq/3/g").argument == .float(0.9) })

            mirror.resetEQBand(kick, 2)

            #expect(await eventually { fake.value(at: "/ch/01/eq/2/g") == .float(0.5) })
            #expect(fake.value(at: "/ch/01/eq/3/g") == .float(0.9))
        }
    }
}

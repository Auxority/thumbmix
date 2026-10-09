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
        #expect(Catalog.eqDefaults(kick)?.map(\.frequency) == [91.4, 418, 1910, 8730])
        for strip in sixBandStrips {
            let defaults = Catalog.eqDefaults(strip)
            #expect(defaults?.map(\.frequency) == [54.5, 153.5, 418, 1140, 3210, 8730], "\(strip)")
            #expect(defaults?.allSatisfy { $0.typeIndex == 2 && $0.gain == 0 && $0.q == 1.7 } == true, "\(strip)")
        }
        #expect(Catalog.eqDefaults(StripID(.auxIn, 1)) == nil, "the app shows no bands for aux ins")
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

    /// One source of truth: a row's double-tap restores what Reset bands would.
    @Test func bandRowsResetToTheBandsDefault() {
        let band = Catalog.eqBand(StripID(.matrix, 2), 3)
        #expect(band.frequency.resetValue == 418)
        #expect(band.q.resetValue == 1.7)
        #expect(band.gain.resetValue == 0)
        #expect(Catalog.eqBand(kick, 4).frequency.resetValue == 8730)
    }

    /// Matrices and mains offer 14 types; the defaults use only PEQ, which sits at the same index for all.
    @Test func resetBandsOnAMainWritesPEQ() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        let main = StripID(.mainStereo)
        fake.deskChange("/main/st/eq/6/type", .int(13))
        #expect(await eventually { mirror.cell("/main/st/eq/6/type").argument == .int(13) })

        mirror.resetEQBands(main)

        let specs = Catalog.eqBand(main, 6)
        #expect(await eventually { fake.value(at: specs.type.address) == .int(2) })
        #expect(await eventually { abs((deskValue(fake, specs.frequency) ?? 0) - 8730) < 1 })
    }

    /// The doc doesn't say which types ignore gain and Q; cut filters have no level to shape (assumed, see TODO).
    @Test func onlyShapingTypesUseGainAndQ() {
        for type in ["LShv", "PEQ", "VEQ", "HShv"] { #expect(Catalog.eqTypeShapesLevel(type), "\(type)") }
        for type in ["LCut", "HCut", "BU6", "BU12", "BS12", "LR12", "BU18", "BU24", "BS24", "LR24"] {
            #expect(!Catalog.eqTypeShapesLevel(type), "\(type)")
        }
    }

    /// Main LR's type 7 is BU12, a type inputs don't have: the band's own type list decides.
    @Test func mirrorTellsWhetherABandShapesLevel() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        #expect(mirror.eqBandShapesLevel(kick, 1) == true, "the demo's bands are PEQs")

        fake.deskChange("/ch/01/eq/1/type", .int(0))
        fake.deskChange("/main/st/eq/2/type", .int(7))

        #expect(await eventually { mirror.eqBandShapesLevel(kick, 1) == false })
        #expect(await eventually { mirror.eqBandShapesLevel(StripID(.mainStereo), 2) == false })
        #expect(mirror.eqBandShapesLevel(StripID(.mainStereo), 3) == true)
    }

    @Test func resetBandsPutsEveryBandBackToItsDefault() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        fake.deskChange("/ch/01/eq/1/type", .int(0))
        fake.deskChange("/ch/01/eq/3/g", .float(0.9))
        #expect(await eventually { mirror.cell("/ch/01/eq/3/g").argument == .float(0.9) })

        mirror.resetEQBands(kick)

        let expected: [(hertz: Double, band: Int)] = [(91.4, 1), (418, 2), (1910, 3), (8730, 4)]
        for (hertz, band) in expected {
            let specs = Catalog.eqBand(kick, band)
            #expect(
                await eventually {
                    deskValue(fake, specs.type) == 2 && deskValue(fake, specs.gain) == 0
                        && abs((deskValue(fake, specs.frequency) ?? 0) - hertz) < hertz * 0.01
                        && abs((deskValue(fake, specs.q) ?? 0) - 1.7) < 0.05
                }, "band \(band)")
        }
    }

    @Test func resetOneBandLeavesTheOthers() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port: port)
        defer { mirror.stop() }
        fake.deskChange("/ch/01/eq/2/g", .float(0.9))
        fake.deskChange("/ch/01/eq/3/g", .float(0.9))
        #expect(await eventually { mirror.cell("/ch/01/eq/3/g").argument == .float(0.9) })

        mirror.resetEQBand(kick, 2)

        #expect(await eventually { fake.value(at: "/ch/01/eq/2/g") == .float(0.5) })
        #expect(fake.value(at: "/ch/01/eq/3/g") == .float(0.9))
    }
}

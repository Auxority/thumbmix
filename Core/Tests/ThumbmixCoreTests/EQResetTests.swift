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

    @Test func onlyInputChannelsHaveDefaults() {
        #expect(Catalog.eqDefaults(kick)?.count == 4)
        #expect(Catalog.eqDefaults(StripID(.bus, 1)) == nil)
        #expect(Catalog.eqDefaults(StripID(.mainStereo)) == nil)
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

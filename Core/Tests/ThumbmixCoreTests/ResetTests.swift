import FakeM32
import Testing

@testable import ThumbmixCore

/// Reset gate, Reset comp and Reset input (EQ's are in `EQResetTests`).
@MainActor
struct ResetTests {
    private let kick = StripID(.input, 1)

    /// What the console holds for `spec`, in real units.
    private func deskValue(_ fake: FakeM32, _ spec: ParamSpec) -> Double? {
        fake.value(at: spec.address).flatMap(spec.scale.normalized(from:)).map(spec.scale.value(fromNormalized:))
    }

    /// Where `value` lands on the desk's grid: what a reset writes and reads back.
    private func snapped(_ spec: ParamSpec, _ value: Double) -> Double {
        spec.scale.value(fromNormalized: spec.scale.normalized(forValue: value))
    }

    private func value(of spec: ParamSpec, in defaults: [(spec: ParamSpec, value: Double)]) -> Double? {
        defaults.first { $0.spec.address == spec.address }?.value
    }

    /// One source of truth: a row's double-tap restores what the tab's Reset would.
    @Test func doubleTapsRestoreTheResetValues() throws {
        let dynamics = Catalog.dynamics(kick)
        let comp = Catalog.dynamicsDefaults(kick)
        for spec in [dynamics.ratio, dynamics.makeup, dynamics.mix] {
            #expect(spec.resetValue != nil && value(of: spec, in: comp) == spec.resetValue, "\(spec.address)")
        }
        let input = Catalog.inputDefaults(kick, headamp: 32)
        let delay = try #require(Catalog.delay(kick))
        for spec in [Catalog.headampGain(32), Catalog.trim(kick), delay.time] {
            #expect(spec.resetValue != nil && value(of: spec, in: input) == spec.resetValue, "\(spec.address)")
        }
    }

    /// The decided values (2026-10-27), provisional until m32-probe section 20 reads the desk's own.
    @Test func defaultsAreTheHarmlessShapes() throws {
        let gate = Catalog.gate(kick)
        let gateDefaults = Catalog.gateDefaults(kick)
        #expect(value(of: gate.mode, in: gateDefaults) == 3, "GATE")
        #expect(value(of: gate.threshold, in: gateDefaults) == -80, "always open")
        let dynamics = Catalog.dynamics(kick)
        let comp = Catalog.dynamicsDefaults(kick)
        #expect(value(of: dynamics.mode, in: comp) == 0, "COMP")
        #expect(value(of: dynamics.threshold, in: comp) == 0, "compresses nothing")
        #expect(value(of: dynamics.envelope, in: comp) == 1, "LOG")
        #expect(Catalog.dynamicsDefaults(StripID(.matrix, 1)).count == comp.count)
        #expect(Catalog.gateDefaults(StripID(.bus, 1)).isEmpty, "only inputs have a gate")
        #expect(Catalog.dynamicsDefaults(StripID(.auxIn, 1)).isEmpty, "aux ins have no comp")
    }

    /// The shape only: On, the key and where the comp sits are set once and stay.
    private func untouched(_ strip: StripID) -> [String] {
        [Catalog.gate(strip).on.address, Catalog.dynamics(strip).on.address]
            + Catalog.gateKey(strip).addresses + Catalog.dynamicsKey(strip).addresses
            + [Catalog.dynamicsPosition(strip)?.address].compactMap { $0 }
    }

    @Test func resetGateWritesItsShapeAndLeavesOnAndKey() async throws {
        try await withLiveDesk { fake, mirror in
            await openTab(.gate, of: kick, in: mirror)
            await openTab(.comp, of: kick, in: mirror)
            let gate = Catalog.gate(kick)
            fake.deskChange(gate.threshold.address, .float(0.9))
            fake.deskChange(gate.mode.address, .int(0))
            #expect(await eventually { mirror.cell(gate.threshold.address).argument == .float(0.9) })

            mirror.resetGate(kick)

            for (spec, value) in Catalog.gateDefaults(kick) {
                #expect(await eventually { deskValue(fake, spec) == snapped(spec, value) }, "\(spec.address)")
            }
            let written = Set(fake.receivedSets.map(\.address))
            #expect(written.isDisjoint(with: untouched(kick)), "wrote \(written.intersection(untouched(kick)))")
        }
    }

    @Test func resetCompWritesItsShapeAndLeavesOnKeyAndPosition() async throws {
        try await withLiveDesk { fake, mirror in
            await openTab(.comp, of: kick, in: mirror)
            let dynamics = Catalog.dynamics(kick)
            fake.deskChange(dynamics.ratio.address, .int(11))
            fake.deskChange(dynamics.auto.address, .int(1))
            #expect(await eventually { mirror.cell(dynamics.auto.address).argument == .int(1) })

            mirror.resetDynamics(kick)

            for (spec, value) in Catalog.dynamicsDefaults(kick) {
                #expect(await eventually { deskValue(fake, spec) == snapped(spec, value) }, "\(spec.address)")
            }
            let written = Set(fake.receivedSets.map(\.address))
            #expect(written.isDisjoint(with: untouched(kick)), "wrote \(written.intersection(untouched(kick)))")
        }
    }

    /// Gain, trim, polarity and delay; 48V never, though it sits on the same preamp.
    @Test func resetInputLeaves48VAlone() async throws {
        try await withLiveDesk { fake, mirror in
            await openTab(.input, of: kick, in: mirror)
            let headamp = try #require(mirror.headamp(of: kick))
            let delay = try #require(Catalog.delay(kick))
            let polarity = try #require(Catalog.invert(kick))
            fake.deskChange(Catalog.trim(kick).address, .float(0.9))
            fake.deskChange(polarity.address, .int(1))
            fake.deskChange(delay.on.address, .int(1))
            fake.deskChange(Catalog.headampPhantom(headamp).address, .int(1))
            #expect(await eventually { mirror.cell(delay.on.address).argument == .int(1) })

            mirror.resetInput(kick)

            for (spec, value) in Catalog.inputDefaults(kick, headamp: headamp) {
                #expect(await eventually { deskValue(fake, spec) == snapped(spec, value) }, "\(spec.address)")
            }
            #expect(!fake.receivedSets.contains { $0.address.hasSuffix("/phantom") })
            #expect(fake.value(at: Catalog.headampPhantom(headamp).address) == .int(1))
        }
    }

    /// A linked pair's reset reaches both sides where the desk links the section, so its alert names the pair, as the
    /// screen's title does (mock A, 2026-10-27); where the desk keeps the section per side, it names the side.
    @Test func theAlertNamesThePairWhereTheDeskLinksTheSection() async throws {
        try await withLiveDesk { fake, mirror in
            let guitarL = StripID(.input, 9)
            #expect(mirror.resetName(.gate, of: guitarL) == "Gtr", "the demo desk links Gtr L/R, every preference ticked")
            #expect(mirror.resetName(.input, of: guitarL) == "Gtr")
            #expect(mirror.resetName(.comp, of: kick) == "Kick", "not linked")

            fake.deskChange(LinkSection.dynamics.preferenceAddress, .int(0))

            #expect(await eventually { mirror.resetName(.comp, of: guitarL) == "Gtr L" })
            #expect(mirror.resetName(.eq, of: guitarL) == "Gtr", "EQ still linked")
        }
    }

    /// An aux in on its line jack has no preamp and no delay: only trim and polarity are written.
    @Test func resetInputSkipsWhatTheStripLacks() async throws {
        try await withLiveDesk { fake, mirror in
            let aux = StripID(.auxIn, 1)
            await openTab(.input, of: aux, in: mirror)
            #expect(mirror.headamp(of: aux) == nil)
            fake.deskChange(Catalog.trim(aux).address, .float(0.9))
            #expect(await eventually { mirror.cell(Catalog.trim(aux).address).argument == .float(0.9) })

            mirror.resetInput(aux)

            #expect(await eventually { deskValue(fake, Catalog.trim(aux)) == 0 })
            let polarity = try #require(Catalog.invert(aux))
            #expect(Set(fake.receivedSets.map(\.address)) == [Catalog.trim(aux).address, polarity.address])
        }
    }
}

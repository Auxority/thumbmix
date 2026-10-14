import FakeM32
import Testing

@testable import ThumbmixCore

/// Auto time, the key source and key filter of the gate and comp, and the comp's place before or after the EQ
/// (mocks 2026-10-14-dyn-key, layout A; doc p.25-37).
@MainActor
struct DynamicsKeyTests {
    private let vox = StripID(.input, 1)

    @Test func everyCompHasAutoTimeAndAKeyFilter() {
        for strip in StripKind.allCases.flatMap(StripID.all).filter(\.hasDynamics) {
            let key = Catalog.dynamicsKey(strip)
            #expect(Catalog.dynamics(strip).auto.address == strip.prefix + "/dyn/auto")
            #expect(key.filterOn.address == strip.prefix + "/dyn/filter/on")
            #expect(key.filterType.address == strip.prefix + "/dyn/filter/type")
            #expect(key.filterFrequency.address == strip.prefix + "/dyn/filter/f")
        }
    }

    /// The doc lists `dyn/keysrc` for channels and buses only, `gate/keysrc` for channels (p.25, p.28).
    @Test func onlyChannelsAndBusesHaveACompKeySource() {
        #expect(Catalog.dynamicsKey(vox).sourceAddress == "/ch/01/dyn/keysrc")
        #expect(Catalog.dynamicsKey(StripID(.bus, 3)).sourceAddress == "/bus/03/dyn/keysrc")
        #expect(Catalog.dynamicsKey(StripID(.matrix, 1)).sourceAddress == nil)
        #expect(Catalog.dynamicsKey(StripID(.mainStereo)).sourceAddress == nil)
        #expect(Catalog.gateKey(vox).sourceAddress == "/ch/01/gate/keysrc")
        #expect(Catalog.gateKey(vox).filterOn.address == "/ch/01/gate/filter/on")
    }

    @Test func theKeyFilterHasTheDesksNineTypesAndRange() {
        let key = Catalog.gateKey(vox)
        #expect(key.filterType.scale.steps == 9)
        #expect(key.filterFrequency.scale == .log(min: 20, max: 20_000, steps: 201))
    }

    /// 0 is the strip itself ("self" in the X32 manual; OFF in the doc), then In 1-32, Aux 1-6, USB L/R (aux 7-8),
    /// FX 1L-4R (the 8 FX returns) and Bus 1-16 (p.25).
    @Test func keySourceNamesEachSourceByNumberAndName() {
        let names: [StripID: String] = [StripID(.input, 3): "Kick", StripID(.bus, 5): "Wedge 1"]
        let spec = Catalog.keySource("/ch/01/dyn/keysrc") { names[$0] ?? "" }
        guard case .choice(let options) = spec.scale else {
            Issue.record("not a choice")
            return
        }
        #expect(options.count == 65)
        #expect(options[0] == "Self")
        #expect(options[3] == "Ch 3 · Kick")
        #expect(options[4] == "Ch 4")
        #expect(options[33] == "Aux 1")
        #expect(options[38] == "Aux 6")
        #expect(options[39] == "USB L")
        #expect(options[40] == "USB R")
        #expect(options[41] == "FX 1L")
        #expect(options[42] == "FX 1R")
        #expect(options[48] == "FX 4R")
        #expect(options[53] == "Bus 5 · Wedge 1")
        #expect(options[64] == "Bus 16")
    }

    @Test func compPositionNamesItsTwoPlaces() {
        #expect(Catalog.dynamicsPosition(vox)?.optionNames == ["Before EQ", "After EQ"])
    }

    /// A send tapped just before or after the EQ hears the comp or not depending on where it sits; one tapped at the
    /// fader hears it either way. The desk keeps one tap per pair of buses, on the odd send (p.26).
    @Test func movingTheCompNamesTheMixesThatWouldChange() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        setBus(1, "Wedge 1", tap: .postEQ, on: true, in: fake)
        setBus(2, "Wedge 2", tap: nil, on: false, in: fake)
        setBus(3, "IEM L", tap: .preEQ, on: true, in: fake)
        setBus(4, "IEM R", tap: nil, on: true, in: fake)
        fake.deskChange("/config/buslink/3-4", .int(1))
        setBus(5, "Wedge 5", tap: .preFader, on: true, in: fake)
        setBus(7, "FX", tap: .postEQ, on: false, in: fake)
        setBus(8, "", tap: nil, on: false, in: fake)
        let mirror = await liveMirror(port: port)
        await openTab(.comp, of: vox, in: mirror)
        #expect(mirror.mixesChangedByMovingComp(of: vox) == ["Wedge 1", "IEM"])
    }

    @Test func nothingIsNamedBeforeTheTapsAreRead() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port: port)
        #expect(mirror.mixesChangedByMovingComp(of: vox) == nil, "unknown, not 'no mixes'")
        await openTab(.comp, of: vox, in: mirror)
        #expect(mirror.mixesChangedByMovingComp(of: vox) != nil)
    }

    @Test func aStripWithoutSendsChangesNoMix() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = await liveMirror(port: port)
        #expect(mirror.mixesChangedByMovingComp(of: StripID(.matrix, 1)) == [])
    }

    private func setBus(_ number: Int, _ name: String, tap: SendTap?, on: Bool, in fake: FakeM32) {
        let bus = StripID(.bus, number)
        fake.deskChange(bus.name, .string(name))
        fake.deskChange(Catalog.sendOn(from: vox, to: bus).address, .int(on ? 1 : 0))
        if let tap, let spec = Catalog.sendTap(from: vox, to: bus) { fake.deskChange(spec.address, .int(Int32(tap.rawValue))) }
    }
}

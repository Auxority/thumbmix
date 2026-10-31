import FakeM32
import Foundation
import Testing

@testable import ThumbmixCore

/// The tools against the fake desk, through a real HTTP connection: what they read, what lands on the desk, and what
/// they refuse (the safety rule: never write a value the desk didn't send, never write while contact is lost).
@MainActor
struct RemoteDeskTests {
    private let kick = StripID(.input, 1)
    private let bass = StripID(.input, 8)
    private let gtrL = StripID(.input, 9)
    private let gtrR = StripID(.input, 10)

    private func list(_ result: JSON) -> [JSON] {
        if case .array(let items)? = result.structured?["strips"] { items } else { [] }
    }

    @Test func aClientCanInitializeListToolsAndListStrips() async throws {
        try await withLiveDesk { _, mirror in
            try await withRemote(mirror) { client in
                let initialize = try await client.rpc("initialize", ["protocolVersion": "2025-11-25"])
                #expect(initialize.result?["protocolVersion"] == "2025-11-25")
                let initialized = try await client.post("/mcp", ["jsonrpc": "2.0", "method": "notifications/initialized"])
                #expect(initialized.status == 202)
                let tools = try await client.rpc("tools/list", headers: ["MCP-Protocol-Version": "2025-11-25"])
                #expect(tools.result?["tools"] != nil)

                let result = try await client.call("list_strips")

                #expect(!result.isError)
                let strips = list(result)
                #expect(strips.count == 80)
                let kickRow = strips.first { $0["id"] == "ch/01" }
                #expect(kickRow?["name"] == "Kick")
                #expect(kickRow?["named"] == true)
                #expect(kickRow?["kind"] == "input")
                #expect(kickRow?["fader_db"] == 0)
                #expect(kickRow?["muted"] == false)
                #expect(kickRow?["linked_with"] == .null)
                #expect(strips.first { $0["id"] == "ch/09" }?["linked_with"] == "ch/10")
                #expect(strips.first { $0["id"] == "ch/20" }?["named"] == false)
                #expect(strips.first { $0["id"] == "ch/20" }?["fader_db"] == "-inf")
                #expect(result.text.contains("\"Kick\""), "the text content carries the same JSON")
            }
        }
    }

    @Test func listStripsCanBeNarrowedToNamedStripsOfOneKind() async throws {
        try await withLiveDesk { _, mirror in
            try await withRemote(mirror) { client in
                let named = list(try await client.call("list_strips", ["kind": "input", "named_only": true]))
                #expect(named.count == 14)
                #expect(named.allSatisfy { $0["kind"] == "input" })

                let bad = try await client.call("list_strips", ["kind": "guitar"])
                #expect(bad.isError)
                #expect(bad.text.contains("input"))
            }
        }
    }

    @Test func getStripReadsItsTabsAndReportsRealUnits() async throws {
        try await withLiveDesk { _, mirror in
            try await withRemote(mirror) { client in
                let result = try await client.call("get_strip", ["strip": "bass"])

                #expect(!result.isError)
                let strip = try #require(result.structured)
                #expect(strip["id"] == "ch/08")
                #expect(strip["name"] == "Bass")
                #expect(strip["fader_db"] == 0)
                #expect(strip["muted"] == false)
                #expect(strip["pan"] == 0)
                #expect(strip["linked_with"] == .null)
                #expect(strip["eq"]?["on"] == true)
                guard case .array(let bands)? = strip["eq"]?["bands"] else {
                    Issue.record("no EQ bands")
                    return
                }
                #expect(bands.count == 4)
                #expect(bands[0]["band"] == 1)
                #expect(bands[0]["type"] == "PEQ")
                #expect(bands[0]["freq_hz"] == 124.7)
                #expect(bands[0]["gain_db"] == 0)
                #expect(bands[0]["q"] == 1.96, "the desk's own step next to its reset value 2")
                #expect(bands[3]["type"] == "HShv")
                #expect(strip["comp"]?["on"] == true)
                #expect(strip["comp"]?["mode"] == "COMP")
                #expect(strip["comp"]?["threshold_db"] == -30)
                #expect(strip["comp"]?["ratio"] == 2)
                #expect(strip["comp"]?["attack_ms"] == 60)
                #expect(strip["comp"]?["makeup_db"] == 12)
                #expect(strip["comp"]?["auto_time"] == false)
                #expect(strip["gate"]?["threshold_db"] == -40)
            }
        }
    }

    @Test func aStripWithoutEQOrCompLeavesThemOut() async throws {
        try await withLiveDesk { _, mirror in
            try await withRemote(mirror) { client in
                let dca = try await client.call("get_strip", ["strip": "drums"])

                #expect(dca.structured?["id"] == "dca/1")
                #expect(dca.structured?["eq"] == nil)
                #expect(dca.structured?["comp"] == nil)
                let aux = try await client.call("get_strip", ["strip": "fxrtn/1"])
                #expect(aux.structured?["comp"] == nil)
                #expect(aux.structured?["gate"] == nil)
                #expect(aux.structured?["eq"] != nil)
            }
        }
    }

    @Test func anAmbiguousOrUnknownNameIsAnErrorThatListsWhatToUse() async throws {
        try await withLiveDesk { _, mirror in
            try await withRemote(mirror) { client in
                let ambiguous = try await client.call("get_strip", ["strip": "tom"])
                #expect(ambiguous.isError)
                #expect(ambiguous.text.contains("Tom 1 (ch/04)"))
                #expect(ambiguous.text.contains("Tom 2 (ch/05)"))

                let unknown = try await client.call("set_mute", ["strip": "trombone", "muted": true])
                #expect(unknown.isError)
                #expect(unknown.text.contains("list_strips"))
            }
        }
    }

    // MARK: Writes

    @Test func writesLandOnTheDeskSnappedToItsSteps() async throws {
        try await withLiveDesk { fake, mirror in
            try await withRemote(mirror) { client in
                let eq = try await client.call(
                    "set_eq_band", ["strip": "Bass", "band": 2, "gain_db": 3, "freq_hz": 100, "q": 1.5, "type": "VEQ"])

                #expect(!eq.isError)
                let spec = Catalog.eqBand(bass, 2)
                let wanted = Catalog.deskArguments([
                    (spec.gain, 3), (spec.frequency, 100), (spec.q, 1.5), (spec.type, 3),
                ])
                for write in wanted {
                    #expect(await eventually { fake.value(at: write.address) == write.argument }, "\(write.address)")
                }
                let changed = eq.structured?["changed"]
                #expect(changed?["gain_db"] == ["from": 0, "to": 3])
                #expect(changed?["type"] == ["from": "PEQ", "to": "VEQ"])
                guard case .number(let snapped)? = changed?["freq_hz"]?["to"] else {
                    Issue.record("no frequency in \(String(describing: changed))")
                    return
                }
                #expect(abs(snapped - 100) < 2 && snapped != 100, "the desk holds its own step: \(snapped)")

                let fader = try await client.call("set_fader", ["strip": "kick", "db": -10])
                let level = Catalog.deskArguments([(Catalog.fader(kick), -10)])[0]
                #expect(await eventually { fake.value(at: level.address) == level.argument })
                #expect(fader.structured?["changed"]?["fader_db"]?["from"] == 0)

                let down = try await client.call("set_fader", ["strip": "ch/01", "db": -90])
                #expect(down.structured?["changed"]?["fader_db"]?["to"] == "-inf")
                #expect(await eventually { fake.value(at: kick.fader) == .float(0) })

                _ = try await client.call("set_mute", ["strip": "ch/01", "muted": true])
                #expect(await eventually { fake.value(at: kick.on) == .int(0) })
                _ = try await client.call("set_mute", ["strip": "Kick", "muted": false])
                #expect(await eventually { fake.value(at: kick.on) == .int(1) })
            }
        }
    }

    @Test func aCompChangeWritesOnlyWhatWasAsked() async throws {
        try await withLiveDesk { fake, mirror in
            try await withRemote(mirror) { client in
                let result = try await client.call(
                    "set_comp",
                    ["strip": "Kick", "threshold_db": -20, "ratio": 4, "makeup_db": 6, "attack_ms": 10, "release_ms": 200, "on": false])

                #expect(!result.isError)
                let dynamics = Catalog.dynamics(kick)
                let ratio = Double(Catalog.ratios.firstIndex(of: "4.0") ?? 0)
                let wanted = Catalog.deskArguments([
                    (dynamics.threshold, -20), (dynamics.ratio, ratio), (dynamics.makeup, 6), (dynamics.attack, 10),
                    (dynamics.release, 200), (dynamics.on, 0),
                ])
                for write in wanted {
                    #expect(await eventually { fake.value(at: write.address) == write.argument }, "\(write.address)")
                }
                #expect(Set(fake.receivedSets.map(\.address)) == Set(wanted.map(\.address)))
                #expect(result.structured?["changed"]?["on"] == ["from": true, "to": false])
                #expect(result.structured?["changed"]?["ratio"] == ["from": 2, "to": 4])
            }
        }
    }

    @Test func aLinkedPairIsWrittenThroughOneSideAsTheAppDoes() async throws {
        try await withLiveDesk { fake, mirror in
            try await withRemote(mirror) { client in
                let result = try await client.call("set_eq_band", ["strip": "Gtr L", "band": 1, "gain_db": 2])

                #expect(!result.isError)
                #expect(result.structured?["also_applied_to"] == "ch/10")
                let write = Catalog.deskArguments([(Catalog.eqBand(gtrL, 1).gain, 2)])[0]
                let partner = Catalog.deskArguments([(Catalog.eqBand(gtrR, 1).gain, 2)])[0]
                #expect(await eventually { fake.value(at: write.address) == write.argument })
                #expect(await eventually { fake.value(at: partner.address) == partner.argument })
                #expect(fake.receivedSets.map(\.address) == [write.address], "the app sent one side; the desk copied it")
            }
        }
    }

    @Test func aValueOutOfRangeOrAnUnfittingRequestIsRefusedAndNothingIsSent() async throws {
        try await withLiveDesk { fake, mirror in
            try await withRemote(mirror) { client in
                let loud = try await client.call("set_eq_band", ["strip": "Bass", "band": 1, "gain_db": 15.5])
                #expect(loud.isError)
                let ratio = try await client.call("set_comp", ["strip": "Bass", "ratio": 6])
                #expect(ratio.isError)
                #expect(ratio.text.contains("one of 1.1, 1.3"))
                let band = try await client.call("set_eq_band", ["strip": "Bass", "band": 5, "gain_db": 1])
                #expect(band.isError)
                #expect(band.text.contains("4 EQ bands"))
                let type = try await client.call("set_eq_band", ["strip": "Bass", "band": 1, "type": "BU24"])
                #expect(type.isError)
                #expect(type.text.contains("PEQ"))
                let nothing = try await client.call("set_comp", ["strip": "Bass"])
                #expect(nothing.isError)
                let noEQ = try await client.call("set_eq_band", ["strip": "drums", "band": 1, "gain_db": 1])
                #expect(noEQ.isError)
                let noComp = try await client.call("set_comp", ["strip": "fxrtn/1", "on": true])
                #expect(noComp.isError)

                #expect(fake.receivedSets.isEmpty)
            }
        }
    }

    // MARK: The safety rule

    @Test func aValueTheDeskNeverSentIsUnknownAndRefusesAllOfAWrite() async throws {
        let unread = Catalog.eqBand(bass, 3).gain.address
        let forgetting: (FakeM32) -> Void = { $0.forget(unread) }
        try await withLiveDesk(before: forgetting) { fake, mirror in
            try await withRemote(mirror, readTimeout: .milliseconds(700)) { client in
                let result = try await client.call("get_strip", ["strip": "Bass"])

                guard case .array(let bands)? = result.structured?["eq"]?["bands"] else {
                    Issue.record("no EQ bands")
                    return
                }
                #expect(bands[2]["gain_db"] == .null, "never read, so unknown, not a guess")
                #expect(bands[2]["freq_hz"] != .null)

                let write = try await client.call("set_eq_band", ["strip": "Bass", "band": 3, "gain_db": 2, "freq_hz": 1000])
                #expect(write.isError)
                #expect(write.text.contains("not been read"))
                #expect(fake.receivedSets.isEmpty, "the frequency was readable, but half a write is no write")
            }
        }
    }

    @Test func writesAndReadsAreRefusedWhileContactIsLost() async throws {
        try await withLiveDesk { fake, mirror in
            try await withRemote(mirror) { client in
                fake.silent = true
                #expect(await eventually { mirror.status == .lost })

                let write = try await client.post("/api/tools/set_fader", ["strip": "Kick", "db": -5])
                #expect(write.status == 503)
                #expect(write.json?.isError == true)
                #expect(write.json?.text.contains("lost") == true)
                let read = try await client.call("get_strip", ["strip": "Kick"])
                #expect(read.isError)
                #expect(read.text.contains("lost"))
                #expect(fake.receivedSets.isEmpty)
            }
        }
    }
}

import FakeM32
import Foundation
import Testing

@testable import ThumbmixCore

/// `get_strip` shows the preamp gain and 48V as the app's Input tab does, and never writes them (no tool for it: 48V can
/// harm a mic that doesn't want it, and gain is the engineer's own).
@MainActor
struct RemotePreampTests {

    @Test func getStripReadsGainAnd48VFromThePreampThatFeedsTheStrip() async throws {
        let gain = Catalog.headampGain(32).address
        let phantom = Catalog.headampPhantom(32).address
        let setUp: (FakeM32) -> Void = {
            $0.deskChange(gain, .float(0.25))
            $0.deskChange(phantom, .int(1))
        }
        try await withLiveDesk(before: setUp) { _, mirror in
            try await withRemote(mirror) { client in
                let result = try await client.call("get_strip", ["strip": "Kick"])

                #expect(result.structured?["preamp"]?["gain_db"] == 6)
                #expect(result.structured?["preamp"]?["phantom_48v"] == true)
                #expect(result.structured?["preamp"]?["shared_with"] == [])

                let snare = try await client.call("get_strip", ["strip": "Snare"])
                #expect(snare.structured?["preamp"]?["phantom_48v"] == false)
                #expect(snare.structured?["preamp"]?["gain_db"] == 24, "mid-travel on the demo desk")
            }
        }
    }

    @Test func aPreampSharedByTwoStripsSaysSo() async throws {
        try await withLiveDesk { _, mirror in
            try await withRemote(mirror) { client in
                let result = try await client.call("get_strip", ["strip": "Vox 1"])

                #expect(result.structured?["preamp"]?["shared_with"] == ["ch/14"])
            }
        }
    }

    @Test func aStripWithoutAPreampHasNone() async throws {
        try await withLiveDesk { _, mirror in
            try await withRemote(mirror) { client in
                let internalSource = try await client.call("get_strip", ["strip": "ch/15"])
                #expect(internalSource.structured?["preamp"] == .null, "fed from an internal source")
                let aux = try await client.call("get_strip", ["strip": "auxin/1"])
                #expect(aux.structured?["preamp"] == .null, "a line jack")
                let bus = try await client.call("get_strip", ["strip": "bus/1"])
                #expect(bus.structured?["preamp"] == nil, "buses have no preamp to show")
            }
        }
    }

    @Test func aValueTheDeskNeverSentIsNull() async throws {
        let unread = Catalog.headampGain(33).address
        let forgetting: (FakeM32) -> Void = { $0.forget(unread) }
        try await withLiveDesk(before: forgetting) { _, mirror in
            try await withRemote(mirror, readTimeout: .milliseconds(700)) { client in
                let result = try await client.call("get_strip", ["strip": "Snare"])

                #expect(result.structured?["preamp"]?["gain_db"] == .null)
                #expect(result.structured?["preamp"]?["phantom_48v"] == false)
            }
        }
    }

    @Test func thereIsNoToolThatWritesThem() async throws {
        try await withRemote(idleMirror()) { client in
            let list = try await client.get("/api/tools")
            guard case .array(let tools)? = list.json?["tools"] else {
                Issue.record("no tools")
                return
            }
            for tool in tools {
                let properties = tool["inputSchema"]?["properties"]?.object ?? [:]
                #expect(!properties.keys.contains { $0.contains("gain_db") && tool["name"] != "set_eq_band" })
                #expect(!properties.keys.contains { $0.contains("48") || $0.contains("phantom") })
            }
        }
    }
}

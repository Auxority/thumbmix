import FakeM32
import Testing
@testable import ThumbmixCore

struct DiscoveryTests {
    @Test func sweepCoversTheSlash24ExceptMe() {
        let hosts = Discovery.sweepHosts(around: "192.168.1.37")
        #expect(hosts.count == 253)
        #expect(hosts.first == "192.168.1.1")
        #expect(hosts.last == "192.168.1.254")
        #expect(!hosts.contains("192.168.1.37"))
    }

    @Test func invalidAddressSweepsNothing() {
        #expect(Discovery.sweepHosts(around: "not an ip").isEmpty)
    }

    @Test(arguments: ["192.168.1.10", "10.0.0.1"]) func validIPv4(_ host: String) {
        #expect(Discovery.isValidIPv4(host))
    }

    @Test(arguments: ["", "192.168.1", "192.168.1.300", "m32.local", "1.2.3.4; rm"]) func invalidIPv4(_ host: String) {
        #expect(!Discovery.isValidIPv4(host))
    }

    @Test func scanFindsTheFake() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }

        let found = await Discovery.scan(hosts: ["127.0.0.1"], port: port, timeout: 1)

        #expect(found == [DiscoveredConsole(host: "127.0.0.1", name: "Fake M32", model: "M32")])
    }
}

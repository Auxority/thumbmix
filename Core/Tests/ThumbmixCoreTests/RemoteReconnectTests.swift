import FakeM32
import Foundation
import Testing

@testable import ThumbmixCore

/// `thumbmix-mcp` may start before the desk answers: the link gives up when the first identify gets no reply, and the
/// server then tries again with a fresh mirror, so the engineer needn't restart Claude Code.
@MainActor
struct RemoteReconnectTests {
    private let quick = LinkTiming(
        identifyTimeout: .milliseconds(200), tick: .milliseconds(50), renewEvery: .milliseconds(500),
        probeWhenQuietFor: .milliseconds(250), lostAfter: .seconds(1), restartAfterLost: .seconds(1))

    @Test func aDeskThatAnswersLaterIsConnectedWithoutARestart() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let first = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9, timing: quick), auditAddresses: [])
        first.start()
        let server = RemoteServer(mirror: first)
        let timing = quick
        let supervising = Task {
            await server.keepConnected(retryEvery: .milliseconds(100)) {
                ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port, timing: timing))
            }
        }
        defer { supervising.cancel() }

        #expect(await eventually { first.failure != nil }, "nothing answers on the dead port")
        #expect(await eventually(timeout: syncTimeout) { server.tools.mirror.isLive }, "the retry found the fake")
        #expect(server.tools.mirror !== first)
        server.tools.mirror.stop()
    }

    @Test func aMirrorThatIsStillTryingIsLeftAlone() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port, timing: quick), auditAddresses: [])
        mirror.start()
        let server = RemoteServer(mirror: mirror)
        var made = 0
        let supervising = Task {
            await server.keepConnected(retryEvery: .milliseconds(50)) {
                made += 1
                return mirror
            }
        }
        defer { supervising.cancel() }

        #expect(await eventually(timeout: syncTimeout) { mirror.isLive })
        try await Task.sleep(for: .milliseconds(300))
        #expect(made == 0)
        #expect(server.tools.mirror === mirror)
        mirror.stop()
    }
}

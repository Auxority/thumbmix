import FakeM32
import Foundation
import Testing

@testable import ThumbmixCore

@MainActor
func eventually(timeout: Duration = .seconds(8), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return condition()
}

func startFake(model: String = "M32") async throws -> (FakeM32, UInt16) {
    let fake = try FakeM32(model: model)
    return (fake, try await fake.start())
}

/// The deadline for any full sync. Suites run in parallel, each syncing ~4000 addresses against its own
/// fake, so a 3-core CI runner needs far longer than this Mac; 10 s failed there once the build cache
/// let the tests start while the runner was still busy.
let syncTimeout = Duration.seconds(30)

/// A mirror that finished its initial sync against the fake on `port`; a mirror that never goes live
/// fails here instead of as a confusing timeout further down the test.
@MainActor
func liveMirror(port: UInt16, auditAddresses: [String] = Catalog.auditAddresses()) async -> ConsoleMirror {
    let mirror = ConsoleMirror(
        link: ConsoleLink(host: "127.0.0.1", port: port, timing: .fast), auditAddresses: auditAddresses)
    mirror.start()
    #expect(await eventually(timeout: syncTimeout) { mirror.isLive }, "the mirror never finished its sync")
    return mirror
}

/// Runs `body` against a fresh fake desk and a mirror that is live on it, and stops both afterwards, however
/// `body` ends. The fake's quirks are set before the mirror connects.
@MainActor
func withLiveDesk(
    copiesLinkedEdits: Bool = true, dropsGets: Int = 0,
    _ body: (FakeM32, ConsoleMirror) async throws -> Void
) async throws {
    let (fake, port) = try await startFake()
    defer { fake.stop() }
    fake.copiesLinkedEdits = copiesLinkedEdits
    fake.dropNextGets(dropsGets)
    let mirror = await liveMirror(port: port)
    defer { mirror.stop() }
    try await body(fake, mirror)
}

/// Opens `tab` of `strip` as the app's screen does: reads its values (and a linked partner's) and waits for them.
@MainActor
func openTab(_ tab: ChannelTab, of strip: StripID, in mirror: ConsoleMirror) async {
    mirror.read(tab, of: strip)
    let strips = [strip] + (mirror.isLinked(strip) ? [strip.partner].compactMap { $0 } : [])
    let addresses = strips.flatMap { Catalog.tabAddresses(tab, $0, headamp: mirror.headamp(of: $0)) }
    #expect(await eventually { addresses.allSatisfy { mirror.cell($0).argument != nil } }, "\(tab) of \(strip) never read")
}

extension Locale {
    /// Fixed formatting for assertions, whatever language the test machine runs in.
    static let testEnglish = Locale(identifier: "en_US_POSIX")
}

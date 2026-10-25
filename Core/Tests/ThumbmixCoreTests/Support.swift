import FakeM32
import Foundation
import Observation
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

/// Without `meters`, the fake streams none: ~80 parallel fakes streaming them at the desk's rate took most of a CI
/// runner's CPU, and syncs missed `syncTimeout` (2026-10-19). Only tests that read meters or the RTA ask for them.
func startFake(model: String = "M32", meters: Bool = false) async throws -> (FakeM32, UInt16) {
    let fake = try FakeM32(model: model, streamsMeters: meters)
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
    await syncGate.enter()
    mirror.start()
    #expect(await eventually(timeout: syncTimeout) { mirror.isLive }, "the mirror never finished its sync")
    await syncGate.leave()
    return mirror
}

/// ~80 suites each sync ~4000 addresses at once; on a busy CPU every sync slowed down together and many missed
/// `syncTimeout` (2026-10-20, reproduced with 24 busy processes on this Mac). A few syncs at a time each get a core
/// and finish well inside it; all at once gained no speed, the CPU being the limit.
let syncGate = SyncGate(permits: max(2, ProcessInfo.processInfo.activeProcessorCount / 2))

actor SyncGate {
    private var permits: Int
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(permits: Int) { self.permits = permits }

    func enter() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Hands the permit straight to the next waiting sync, if any.
    func leave() {
        guard waiting.isEmpty else {
            waiting.removeFirst().resume()
            return
        }
        permits += 1
    }
}

/// Runs `body` against a fresh fake desk and a mirror that is live on it, and stops both afterwards, however
/// `body` ends. The fake's quirks are set, and `before` sets the desk's state, before the mirror connects.
@MainActor
func withLiveDesk(
    copiesLinkedEdits: Bool = true, dropsGets: Int = 0, auditAddresses: [String] = Catalog.auditAddresses(),
    meters: Bool = false, before: (FakeM32) -> Void = { _ in },
    body: (FakeM32, ConsoleMirror) async throws -> Void
) async throws {
    let (fake, port) = try await startFake(meters: meters)
    defer { fake.stop() }
    fake.copiesLinkedEdits = copiesLinkedEdits
    fake.dropNextGets(dropsGets)
    before(fake)
    let mirror = await liveMirror(port: port, auditAddresses: auditAddresses)
    defer { mirror.stop() }
    try await body(fake, mirror)
}

/// A live desk on which each of `addresses` (a solo switch, Exclusive solo) was switched on before connecting.
@MainActor
func withLiveDesk(setting addresses: [String], body: (FakeM32, ConsoleMirror) async throws -> Void) async throws {
    try await withLiveDesk(
        before: { fake in
            for address in addresses { fake.deskChange(address, .int(1)) }
        }, body: body)
}

/// Runs `body` against a fresh fake desk and a link already started on it, and stops both afterwards. `before`
/// sets the fake's quirks ahead of the first identify.
@MainActor
func withLink(
    model: String = "M32", before: (FakeM32) -> Void = { _ in },
    body: (FakeM32, ConsoleLink) async throws -> Void
) async throws {
    let (fake, port) = try await startFake(model: model)
    defer { fake.stop() }
    before(fake)
    let link = ConsoleLink(host: "127.0.0.1", port: port, timing: .fast)
    defer { link.stop() }
    link.start()
    try await body(fake, link)
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

/// Counts the changes a view reading only `read` would redraw for.
@MainActor
final class Changes {
    private(set) var count = 0
    private let mirror: ConsoleMirror
    private let read: (ConsoleMirror) -> Void

    init(_ mirror: ConsoleMirror, _ read: @escaping (ConsoleMirror) -> Void) {
        self.mirror = mirror
        self.read = read
        watch()
    }

    private func watch() {
        withObservationTracking {
            read(mirror)
        } onChange: { [weak self] in
            MainActor.assumeIsolated { self?.record() }
        }
    }

    private func record() {
        count += 1
        watch()
    }
}

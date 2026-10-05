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

/// A mirror that finished its initial sync against the fake on `port`. Suites run in parallel, each
/// syncing ~4000 addresses against its own fake, so a 3-core CI runner gets a generous deadline; a
/// mirror that never goes live fails here instead of as a confusing timeout further down the test.
@MainActor
func liveMirror(port: UInt16) async -> ConsoleMirror {
    let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port, timing: .fast))
    mirror.start()
    #expect(await eventually(timeout: .seconds(30)) { mirror.isLive }, "the mirror never finished its sync")
    return mirror
}

extension Locale {
    /// Fixed formatting for assertions, whatever language the test machine runs in.
    static let testEnglish = Locale(identifier: "en_US_POSIX")
}

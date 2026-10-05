import FakeM32
import Foundation

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

extension Locale {
    /// Fixed formatting for assertions, whatever language the test machine runs in.
    static let testEnglish = Locale(identifier: "en_US_POSIX")
}

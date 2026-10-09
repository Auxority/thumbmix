import FakeM32
import ThumbmixCore
import XCTest

/// Each test talks to its own fake desk, started inside the test runner on a free port: a test sees only its
/// own edits, and tests can run side by side on several simulators. The simulator shares the Mac's localhost.
final class TestDesk: Sendable {
    private let fake: FakeM32
    let port: UInt16

    private init(fake: FakeM32, port: UInt16) {
        self.fake = fake
        self.port = port
    }

    /// Stopped when the test ends. Nil after a failure, which ends the test (`continueAfterFailure` is false).
    static func start(for test: XCTestCase) -> TestDesk? {
        guard let fake = try? FakeM32() else {
            XCTFail("could not create the fake desk")
            return nil
        }
        let started = StartedPort()
        let listening = XCTestExpectation(description: "the fake desk listens")
        Task.detached {
            started.port = try? await fake.start()
            listening.fulfill()
        }
        XCTWaiter().wait(for: [listening], timeout: 5)
        guard let port = started.port else {
            XCTFail("the fake desk didn't start")
            return nil
        }
        test.addTeardownBlock { fake.stop() }
        return TestDesk(fake: fake, port: port)
    }

    /// Launch arguments that connect the app straight to this desk.
    var connect: [String] { ["-lastConsoleHost", "127.0.0.1", "-consolePort", String(port)] }

    /// Plays the engineer changing a setting on the desk itself.
    func change(_ address: String, _ value: Int32) {
        fake.deskChange(address, .int(value))
    }

    /// What the desk holds now, as the app's edits left it.
    func value(_ address: String) -> OSCArgument? {
        fake.value(at: address)
    }
}

/// Written once by the starting task, read after the wait: never at the same time.
private final class StartedPort: @unchecked Sendable {
    var port: UInt16?
}

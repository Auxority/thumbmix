import XCTest

/// A UI test with the app connected to the test's own fake desk.
@MainActor
class DeskUITestCase: XCTestCase {
    var app: XCUIApplication!
    /// Started on first use, so a test can change the desk before the app launches.
    lazy var desk: TestDesk! = TestDesk.start(for: self)

    override func setUp() {
        continueAfterFailure = false
    }

    /// Launched per test rather than in setUp: the setUp override is nonisolated, XCUIApplication is main-actor.
    func launch(_ arguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = desk.connect + arguments + fixedLocale
        app.launch()
        // Names show while the sync still runs and the rows are disabled; a tap then does nothing. With several
        // simulators sharing the Mac, the sync can outlast the first tap.
        let kick = app.buttons["Kick"]
        XCTAssertTrue(eventually(within: 15) { kick.exists && kick.isEnabled })
    }

    /// Waits for the nudge buttons: only the channel screen has them, the overview rows don't.
    func open(_ name: String) {
        app.buttons[name].tap()
        XCTAssertTrue(app.buttons["+1 dB"].appears(within: 3))
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}

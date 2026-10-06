import XCTest

@MainActor
final class OfflineUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Offline mode runs a demo console on the phone itself, marked DEMO on every screen so it's never
    /// mistaken for the desk, and every visit starts from the same fresh desk.
    func testOfflineModeRunsAFreshDemoConsole() {
        let app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", ""] + fixedLocale
        app.launch()

        startOffline(app)
        XCTAssertTrue(app.staticTexts["DEMO"].exists, "the overview says it's the demo")
        app.buttons["Kick"].tap()
        XCTAssertTrue(app.staticTexts["DEMO"].waitForExistence(timeout: 3), "so does a strip screen")
        let fader = app.descendants(matching: .any)["/ch/01/mix/fader"]
        app.buttons["+1 dB"].tap()
        XCTAssertEqual(fader.value as? String, "+1.0 dB")
        saveScreenshot("offline-strip")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Disconnect"].tap()
        startOffline(app)
        app.buttons["Kick"].tap()
        XCTAssertTrue(fader.waitForExistence(timeout: 3))
        XCTAssertEqual(fader.value as? String, "0.0 dB", "a new visit starts from a fresh demo desk")
    }

    private func startOffline(_ app: XCUIApplication) {
        let offline = app.buttons["Try offline (demo console)"]
        XCTAssertTrue(offline.waitForExistence(timeout: 5))
        offline.tap()
        XCTAssertTrue(app.buttons["Kick"].waitForExistence(timeout: 15))
    }
}

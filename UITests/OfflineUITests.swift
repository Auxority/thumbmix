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
        app.launchArguments = ["-knownConsoles", "()"] + fixedLocale
        app.launch()

        startOffline(app)
        XCTAssertTrue(app.staticTexts["DEMO"].exists, "the overview says it's the demo")
        XCTAssertFalse(app.navigationBars.staticTexts["Thumbmix"].exists, "the pill stands alone, without a title")
        saveScreenshot("offline-overview")
        app.buttons["Kick"].tap()
        XCTAssertTrue(app.staticTexts["DEMO"].appears(within: 3), "so does a strip screen")
        let fader = app.descendants(matching: .any)["/ch/01/mix/fader"]
        fader.press(forDuration: 0.8)
        let alert = app.alerts["Fader"]
        XCTAssertTrue(alert.appears(within: 2))
        alert.textFields.firstMatch.typeText("1")
        alert.buttons["Set"].tap()
        XCTAssertTrue(eventually(within: 2) { fader.value as? String == "+1.0 dB" })
        saveScreenshot("offline-strip")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Disconnect"].tap()
        startOffline(app)
        app.buttons["Kick"].tap()
        XCTAssertTrue(fader.appears(within: 3))
        XCTAssertEqual(fader.value as? String, "0.0 dB", "a new visit starts from a fresh demo desk")
    }

    private func startOffline(_ app: XCUIApplication) {
        let offline = app.buttons["Try a demo console"]
        XCTAssertTrue(offline.appears(within: 5))
        offline.tap()
        // Names show while the sync still runs and the rows are disabled; a tap then does nothing.
        let kick = app.buttons["Kick"]
        XCTAssertTrue(eventually(within: 15) { kick.exists && kick.isEnabled })
    }
}

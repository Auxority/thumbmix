import XCTest

@MainActor
final class OverviewUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    /// Launched per test rather than in setUp: the setUp override is nonisolated, XCUIApplication is main-actor.
    private func launch() {
        app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", "127.0.0.1"] + fixedLocale
        app.launch()
        XCTAssertTrue(app.buttons["Kick"].waitForExistence(timeout: 15))
    }

    func testHorizontalDragMovesTheFader() {
        launch()
        let fader = app.descendants(matching: .any)["/ch/01/mix/fader"]
        XCTAssertTrue(fader.waitForExistence(timeout: 5))
        let before = fader.value as? String

        fader.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: fader.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)))

        XCTAssertNotEqual(fader.value as? String, before)
    }

    func testVerticalSwipeScrollsInsteadOfMovingFaders() {
        launch()
        let fader = app.descendants(matching: .any)["/ch/01/mix/fader"]
        let before = fader.value as? String
        let frame = app.buttons["Kick"].frame

        app.swipeUp()

        XCTAssertNotEqual(app.buttons["Kick"].frame, frame)
        XCTAssertEqual(fader.value as? String, before)
    }

    func testUnusedChannelsHiddenUntilToggled() {
        launch()
        XCTAssertFalse(app.buttons["Ch 20"].exists)
        app.buttons["Unused"].tap()
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Ch 20"].waitForExistence(timeout: 2))
    }

    func testRowStaysWhileItsFaderIsPulledDown() {
        launch()
        app.swipeUp()
        let row = app.descendants(matching: .any)["/ch/17/mix/fader"]
        XCTAssertTrue(row.waitForExistence(timeout: 2))

        row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5)))

        XCTAssertTrue(app.buttons["Ch 17"].exists)
        XCTAssertEqual(row.value as? String, "−∞ dB")
    }

    func testChipsSwitchGroups() {
        launch()
        app.buttons["Buses"].tap()
        XCTAssertTrue(app.buttons["Mon 1"].waitForExistence(timeout: 2))
    }

    func testMuteToggles() {
        launch()
        let mute = app.buttons["mute-/ch/01/mix/on"]
        mute.tap()
        XCTAssertEqual(mute.label, "Unmute")
        mute.tap()
        XCTAssertEqual(mute.label, "Mute")
    }
}

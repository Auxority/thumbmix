import XCTest

@MainActor
final class OverviewUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", "127.0.0.1"]
        app.launch()
        XCTAssertTrue(app.buttons["Kick"].waitForExistence(timeout: 15))
    }

    func testHorizontalDragMovesTheFader() {
        let fader = app.otherElements["/ch/01/mix/fader"]
        XCTAssertTrue(fader.waitForExistence(timeout: 5))
        let before = fader.value as? String

        fader.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: fader.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)))

        XCTAssertNotEqual(fader.value as? String, before)
    }

    func testVerticalSwipeScrollsInsteadOfMovingFaders() {
        let fader = app.otherElements["/ch/01/mix/fader"]
        let before = fader.value as? String
        let frame = app.buttons["Kick"].frame

        app.swipeUp()

        XCTAssertNotEqual(app.buttons["Kick"].frame, frame)
        XCTAssertEqual(fader.value as? String, before)
    }

    func testUnusedChannelsHiddenUntilToggled() {
        XCTAssertFalse(app.buttons["Ch 20"].exists)
        app.buttons["Unused"].tap()
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Ch 20"].waitForExistence(timeout: 2))
    }

    func testChipsSwitchGroups() {
        app.buttons["Buses"].tap()
        XCTAssertTrue(app.buttons["Mon 1"].waitForExistence(timeout: 2))
    }

    func testMuteToggles() {
        let mute = app.buttons["mute-/ch/01/mix/on"]
        mute.tap()
        XCTAssertEqual(mute.label, "Unmute")
        mute.tap()
        XCTAssertEqual(mute.label, "Mute")
    }
}

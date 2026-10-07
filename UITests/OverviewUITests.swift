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
            .press(
                forDuration: 0.05,
                thenDragTo: fader.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)))

        XCTAssertNotEqual(fader.value as? String, before)
    }

    /// Hiding the unused channels shortens the list; scrolled near its end, the old offset showed
    /// only black until the user scrolled back up by hand.
    func testHidingUnusedFromFarDownShowsTheList() {
        launch()
        app.buttons["Unused"].tap()
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(app.buttons["Kick"].isHittable)
        app.buttons["Unused"].tap()
        XCTAssertTrue(app.buttons["Kick"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Kick"].isHittable)
    }

    /// Switching from far down the inputs to a short group kept the old offset, past that group's end:
    /// the list showed only black.
    func testSwitchingToAShortGroupFromFarDownShowsTheList() {
        launch()
        // Flicked, and the chip tapped while the list still glides, as a thumb does.
        for _ in 0..<3 { app.swipeUp(velocity: .fast) }
        app.buttons["DCA"].tap()
        XCTAssertTrue(app.buttons["Drums"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Drums"].isHittable)
    }

    /// Showing the unused buses moved the used ones up by a few points on iOS 27: the list was
    /// scrolled to an anchor at its very top instead of starting where a list naturally starts.
    func testShowingUnusedKeepsTheRowsInPlace() {
        launch()
        app.buttons["Buses"].tap()
        let mon1 = app.buttons["Mon 1"]
        XCTAssertTrue(mon1.waitForExistence(timeout: 2))
        let before = mon1.frame.minY
        app.buttons["Unused"].tap()
        XCTAssertTrue(app.buttons["Bus 5"].waitForExistence(timeout: 2))
        XCTAssertEqual(mon1.frame.minY, before, accuracy: 0.5)
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
            .press(
                forDuration: 0.05,
                thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5)))

        XCTAssertTrue(app.buttons["Ch 17"].exists)
        XCTAssertEqual(row.value as? String, "−∞ dB")
    }

    func testRowsGrowWithLargerText() {
        app = XCUIApplication()
        app.launchArguments =
            [
                "-lastConsoleHost", "127.0.0.1",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL",
            ] + fixedLocale
        app.launch()
        XCTAssertTrue(app.buttons["Kick"].waitForExistence(timeout: 15))

        let fader = app.descendants(matching: .any)["/ch/01/mix/fader"]
        XCTAssertGreaterThan(fader.frame.height, 70)
        saveScreenshot("dynamic-type-overview")
    }

    /// The engineer finds a channel by its number on the desk as often as by its name.
    func testEachRowShowsItsChannelNumber() {
        launch()
        XCTAssertEqual(app.buttons["Kick"].value as? String, "1")
        XCTAssertEqual(app.buttons["Vox 2"].value as? String, "14")
        saveScreenshot("channel-numbers")
        app.buttons["Main"].tap()
        XCTAssertTrue(app.buttons["LR"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["LR"].value as? String, "", "a main bus has no number")
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

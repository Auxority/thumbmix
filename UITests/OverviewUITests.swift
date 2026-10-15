import XCTest

@MainActor
final class OverviewUITests: DeskUITestCase {
    func testHorizontalDragMovesTheFader() {
        launch()
        let fader = app.descendants(matching: .any)["/ch/01/mix/fader"]
        XCTAssertTrue(fader.appears(within: 5))
        let before = fader.value as? String

        fader.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
            .press(
                forDuration: 0.05,
                thenDragTo: fader.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)))

        XCTAssertNotEqual(fader.value as? String, before)
    }

    /// A short swipe starting on the fader itself: iOS 27 drops rows scrolled far off screen, so a full swipe
    /// would leave no Kick row to compare.
    func testVerticalSwipeScrollsInsteadOfMovingFaders() {
        launch()
        let fader = app.descendants(matching: .any)["/ch/01/mix/fader"]
        let before = fader.value as? String
        let frame = app.buttons["Kick"].frame

        let start = fader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -120)))

        XCTAssertTrue(eventually(within: 2) { app.buttons["Kick"].frame.minY < frame.minY }, "the list scrolled")
        XCTAssertEqual(fader.value as? String, before)
    }

    func testRowStaysWhileItsFaderIsPulledDown() {
        launch()
        app.swipeUp()
        let row = app.descendants(matching: .any)["/ch/17/mix/fader"]
        XCTAssertTrue(row.appears(within: 2))

        row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            .press(
                forDuration: 0.05,
                thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5)))

        XCTAssertTrue(app.buttons["Ch 17"].exists)
        XCTAssertEqual(row.value as? String, "−∞ dB")
    }

    func testRowsGrowWithLargerText() {
        launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])

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
        // The Main chip sits past the edge of a 375 pt screen: the engineer swipes the chip row first.
        app.buttons["Buses"].swipeLeft()
        app.buttons["Main"].tap()
        XCTAssertTrue(app.buttons["LR"].appears(within: 2))
        XCTAssertEqual(app.buttons["LR"].value as? String, "", "a main bus has no number")
    }

    /// The demo desk links Gtr L/R (9-10): one row named by what both names share, numbered with both channels.
    func testALinkedPairIsOneRow() {
        launch()
        app.swipeUp()
        let pair = app.buttons["Gtr"]
        XCTAssertTrue(pair.appears(within: 2))
        XCTAssertEqual(pair.value as? String, "9-10")
        XCTAssertFalse(app.buttons["Gtr L"].exists)
        XCTAssertFalse(app.buttons["Gtr R"].exists)
        saveScreenshot("pair-row")
        pair.tap()
        XCTAssertTrue(app.buttons["+1 dB"].appears(within: 3))
        XCTAssertTrue(app.descendants(matching: .any)["/ch/09/mix/fader"].exists, "the pair opens on its odd side")
    }

    func testMuteToggles() {
        launch()
        let mute = app.buttons["mute-/ch/01/mix/on"]
        mute.tap()
        XCTAssertEqual(mute.label, "Unmute Kick")
        mute.tap()
        XCTAssertEqual(mute.label, "Mute Kick")
    }
}

import XCTest

@MainActor
final class OverviewUITests: DeskUITestCase {
    /// Each row: its desk number, a mute and a fader that reach the desk and say their strip to VoiceOver (forty rows
    /// of "Fader" and "Mute" tell a VoiceOver user nothing). A vertical swipe scrolls instead of moving a fader. A
    /// linked pair is one row; a row stays while its fader is pulled down; the mains have no number.
    func testHorizontalDragMovesTheFader() {
        launch()
        let fader = element("/ch/01/mix/fader")
        XCTAssertTrue(fader.appears(within: 5))
        eachRowShowsItsChannelNumber()
        muteAndFaderReachTheDesk(fader)
        aVerticalSwipeScrollsInsteadOfMovingFaders(fader)
        aPairIsOneRowAndARowStaysWhilePulledDown()
        app.buttons["Main"].tap()
        XCTAssertTrue(app.buttons["LR"].appears(within: 2))
        XCTAssertEqual(app.buttons["LR"].value as? String, "", "a main bus has no number")
    }

    /// The engineer finds a channel by its number on the desk as often as by its name.
    private func eachRowShowsItsChannelNumber() {
        XCTAssertEqual(app.buttons["Kick"].value as? String, "1")
        XCTAssertEqual(app.buttons["Vox 2"].value as? String, "14")
        saveScreenshot("channel-numbers")
    }

    private func muteAndFaderReachTheDesk(_ fader: XCUIElement) {
        XCTAssertEqual(fader.label, "Kick fader", "VoiceOver")
        let mute = app.buttons["mute-/ch/01/mix/on"]
        XCTAssertEqual(mute.label, "Mute Kick", "VoiceOver")
        mute.tap()
        XCTAssertTrue(eventually(within: 2) { mute.label == "Unmute Kick" })
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/mix/on") == .int(0) }, "muted on the desk")
        mute.tap()
        XCTAssertTrue(eventually(within: 2) { mute.label == "Mute Kick" })
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/mix/on") == .int(1) }, "unmuted on the desk")

        let before = fader.value as? String
        let deskBefore = desk.value("/ch/01/mix/fader")
        fader.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: fader.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)))
        XCTAssertNotEqual(fader.value as? String, before, "a sideways drag moves the fader")
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/mix/fader") != deskBefore }, "the drag reached the desk")
    }

    /// A short swipe starting on the fader itself: iOS 27 drops rows scrolled far off screen, so a full swipe
    /// would leave no Kick row to compare.
    private func aVerticalSwipeScrollsInsteadOfMovingFaders(_ fader: XCUIElement) {
        let before = fader.value as? String
        let frame = app.buttons["Kick"].frame
        let start = fader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -120)))
        XCTAssertTrue(eventually(within: 2) { self.app.buttons["Kick"].frame.minY < frame.minY }, "the list scrolled")
        XCTAssertEqual(fader.value as? String, before, "the fader stayed")
    }

    /// The demo desk links Gtr L/R (9-10): one row named by what both names share, numbered with both channels.
    private func aPairIsOneRowAndARowStaysWhilePulledDown() {
        // From the top, where one swipe brings Ch 17 to the middle of the screen.
        app.swipeDown()
        XCTAssertTrue(eventually(within: 2) { self.app.buttons["Kick"].isHittable })
        app.swipeUp()
        let pair = app.buttons["Gtr"]
        XCTAssertTrue(pair.appears(within: 2))
        XCTAssertEqual(pair.value as? String, "9-10")
        XCTAssertFalse(app.buttons["Gtr L"].exists)
        XCTAssertFalse(app.buttons["Gtr R"].exists)
        saveScreenshot("pair-row")

        let row = element("/ch/17/mix/fader")
        XCTAssertTrue(row.appears(within: 2))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5)))
        XCTAssertTrue(app.buttons["Ch 17"].exists, "the row stays at −∞")
        XCTAssertEqual(row.value as? String, "−∞ dB")
    }
}

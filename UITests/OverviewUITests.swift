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

    /// Switching from far down the inputs to a short group kept the old offset, past that group's end:
    /// the list showed only black.
    func testSwitchingToAShortGroupFromFarDownShowsTheList() {
        launch()
        // Flicked, and the chip tapped while the list still glides, as a thumb does.
        for _ in 0..<3 { app.swipeUp(velocity: .fast) }
        app.buttons["DCA"].tap()
        XCTAssertTrue(app.buttons["Drums"].appears(within: 2))
        XCTAssertTrue(app.buttons["Drums"].isHittable)
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

    /// The Unused toggle is gone until its redesign (TODO): every strip shows, so none is out of reach.
    func testEveryChannelShowsWithoutAToggle() {
        launch()
        XCTAssertTrue(app.buttons["Kick"].appears(within: 5))
        XCTAssertFalse(app.buttons["Unused"].exists)
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Ch 20"].appears(within: 2))
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

    func testChipsSwitchGroups() {
        launch()
        app.buttons["Buses"].tap()
        XCTAssertTrue(app.buttons["Mon 1"].appears(within: 2))
    }

    /// A chip past the screen's edge stays in view once tapped: the bar jumped back to Inputs and Aux.
    func testTappedChipStaysInView() {
        launch()
        app.buttons["Buses"].swipeLeft()
        let main = app.buttons["Main"]
        main.tap()
        XCTAssertTrue(app.buttons["LR"].appears(within: 2))
        sleep(1)  // let a jump back play out before judging where the bar rests
        XCTAssertLessThanOrEqual(main.frame.maxX, app.frame.maxX, "the Main chip is still on screen")
        saveScreenshot("chips-main-tapped")
        XCTAssertTrue(main.isHittable)
    }

    /// The group chips sit along the bottom edge, where a thumb reaches them one-handed, and the list's last
    /// strip still scrolls clear of their bar.
    func testGroupChipsSitWithinThumbReach() {
        launch()
        let inputs = app.buttons["Inputs"]
        XCTAssertGreaterThan(inputs.frame.minY, app.frame.height * 0.75, "the chips sit in the bottom quarter")
        for _ in 0..<6 { app.swipeUp(velocity: .fast) }
        let lastMute = app.buttons["mute-/ch/32/mix/on"]
        XCTAssertTrue(eventually(within: 3) { lastMute.exists && lastMute.frame.maxY <= inputs.frame.minY })
        XCTAssertTrue(lastMute.isHittable)
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

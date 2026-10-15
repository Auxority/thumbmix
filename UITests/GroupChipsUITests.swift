import XCTest

/// The group chips (Inputs, Aux, FX…) in their glass bar at the bottom of the overview.
@MainActor
final class GroupChipsUITests: DeskUITestCase {
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
        XCTAssertTrue(main.settles(within: 3))  // a jump back must play out before we judge where the bar rests
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
}

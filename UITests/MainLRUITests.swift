import XCTest

/// The "to Main LR" pill on the Mix tab's name line (mock 2026-10-13): every tap asks first, both ways.
@MainActor
final class MainLRUITests: DeskUITestCase {
    func testTakingAChannelOutAndBackAsksEachTime() {
        launch()
        open("Kick")
        let pill = element("mainLR-/ch/01/mix/st")
        XCTAssertTrue(pill.appears(within: 2))
        XCTAssertEqual(pill.label, "Kick in the main mix")

        pill.tap()
        let takeOut = app.alerts["Take Kick out of the main mix?"]
        XCTAssertTrue(takeOut.appears(within: 2))
        saveScreenshot("main-lr-alert")
        takeOut.buttons["Take out"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/mix/st") == .int(0) })
        XCTAssertTrue(eventually(within: 2) { pill.label == "Kick out of the main mix" })
        saveScreenshot("main-lr-out")

        pill.tap()
        let sendBack = app.alerts["Send Kick to the main mix?"]
        XCTAssertTrue(sendBack.appears(within: 2))
        sendBack.buttons["Cancel"].tap()
        XCTAssertEqual(desk.value("/ch/01/mix/st"), .int(0), "Cancel changes nothing")
    }

    /// The pill is taller than the name; without a fixed header height the fader sat 4 pt lower on Mix than on EQ.
    func testSwitchingTabsDoesNotMoveTheFader() {
        launch()
        open("Kick")
        XCTAssertTrue(element("mainLR-/ch/01/mix/st").appears(within: 2))
        let onMix = element("/ch/01/mix/fader").frame.minY
        app.buttons["EQ"].tap()
        XCTAssertTrue(eventually(within: 2) { !self.element("mainLR-/ch/01/mix/st").exists })
        XCTAssertEqual(element("/ch/01/mix/fader").frame.minY, onMix, accuracy: 0.5)
    }

    /// Mix tab only; and a matrix has no LR switch on the desk.
    func testThePillShowsOnlyOnTheMixTabOfStripsThatHaveIt() {
        launch()
        open("Kick")
        XCTAssertTrue(element("mainLR-/ch/01/mix/st").appears(within: 2))
        app.buttons["EQ"].tap()
        XCTAssertTrue(eventually(within: 2) { !self.element("mainLR-/ch/01/mix/st").exists }, "not on other tabs")
        app.navigationBars.buttons.firstMatch.tap()
        // The Matrix chip sits past the edge of a 375 pt screen: the engineer swipes the chip row first.
        app.buttons["Buses"].swipeLeft()
        app.buttons["Matrix"].tap()
        open("Fill")
        XCTAssertTrue(element("solo-/-stat/solosw/65").appears(within: 2))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "mainLR-/mtx/01/mix/st").firstMatch.exists)
    }
}

import XCTest

@MainActor
final class ChannelUITests: XCTestCase {
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

    /// Waits for the nudge buttons: only the channel screen has them, the overview rows don't.
    private func open(_ name: String) {
        app.buttons[name].tap()
        XCTAssertTrue(app.buttons["+1 dB"].waitForExistence(timeout: 3))
    }

    func testNudgeButtonsMoveOneDecibel() {
        launch()
        open("Kick")
        let fader = app.descendants(matching: .any)["/ch/01/mix/fader"]
        XCTAssertEqual(fader.value as? String, "0.0 dB")
        app.buttons["+1 dB"].tap()
        XCTAssertEqual(fader.value as? String, "+1.0 dB")
        app.buttons["−1 dB"].tap()
        XCTAssertEqual(fader.value as? String, "0.0 dB")
    }

    /// Like the desk, a preamp channel offers Gain and 48V; trim is for digital sources only (doc fn.18).
    func testPreampChannelShowsGainNotTrim() {
        launch()
        open("Vox 2")
        XCTAssertTrue(app.descendants(matching: .any)["/headamp/044/gain"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["toggle-/headamp/044/phantom"].exists)
        XCTAssertTrue(app.staticTexts["Shared with Vox 1"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["/ch/14/preamp/trim"].exists)
        saveScreenshot("task-13-input")
    }

    func testInternalSourceShowsTrimNotGain() {
        launch()
        app.buttons["Unused"].tap()
        app.swipeUp()
        app.buttons["Ch 15"].tap()
        XCTAssertTrue(
            app.staticTexts["No preamp: this channel reads from an internal source."].waitForExistence(
                timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["/ch/15/preamp/trim"].exists)
        let headampControls = NSPredicate(format: "identifier CONTAINS '/headamp/'")
        XCTAssertEqual(app.descendants(matching: .any).matching(headampControls).count, 0)
    }

    /// Uses DCA 2 ("Band"): the fake keeps every edit, and other tests expect "Drums" and "Vox" untouched.
    func testRenamingADCAReachesTheOverview() {
        launch()
        app.buttons["DCA"].tap()
        open("Band")
        app.buttons["edit-strip"].tap()
        let field = app.textFields["strip-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "Rhythm section")
        XCTAssertEqual(field.value as? String, "Rhythm secti", "the desk stores 12 characters")
        app.buttons["color-green"].tap()
        let search = app.textFields["icon-search"]
        search.tap()
        search.typeText("kit")
        app.buttons["icon-11"].tap()
        saveScreenshot("edit-strip")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Rhythm secti"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Rhythm secti"].waitForExistence(timeout: 3))
    }

    func testCancelLeavesTheDeskUnchanged() {
        launch()
        app.buttons["DCA"].tap()
        open("Vox")
        app.buttons["edit-strip"].tap()
        let field = app.textFields["strip-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("X")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Vox"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["VoxX"].exists)
    }

    func testDCAMembers() {
        launch()
        app.buttons["DCA"].tap()
        open("Drums")
        XCTAssertTrue(app.staticTexts["Snare"].exists)
        XCTAssertFalse(app.staticTexts["Bass"].exists)
    }

    func testGateTabEditsThreshold() {
        launch()
        open("Kick")
        app.buttons["Gate"].tap()
        let threshold = app.descendants(matching: .any)["/ch/01/gate/thr"]
        XCTAssertTrue(threshold.waitForExistence(timeout: 2))
        let before = threshold.value as? String
        threshold.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.05,
                thenDragTo: threshold.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        XCTAssertNotEqual(threshold.value as? String, before)
        XCTAssertTrue(app.descendants(matching: .any)["/ch/01/gate/release"].exists)
        saveScreenshot("task-14-gate")
    }

    func testCompTabShowsRatioAndMakeup() {
        launch()
        open("Kick")
        app.buttons["Comp"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["/ch/01/dyn/ratio"].value as? String, "2.0:1")
        XCTAssertTrue(app.descendants(matching: .any)["/ch/01/dyn/mgain"].exists)
    }

    func testGateAndCompDrawTheirCurves() {
        launch()
        open("Kick")
        app.buttons["Gate"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["gate-graph"].waitForExistence(timeout: 2))
        saveScreenshot("gate-graph")
        app.buttons["Comp"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["comp-graph"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.descendants(matching: .any)["/ch/01/dyn/mode"].value as? String, "COMP")
        saveScreenshot("comp-graph")
    }

    func testBusHasCompButNoGate() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        XCTAssertFalse(app.buttons["Gate"].exists)
        app.buttons["Comp"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["/bus/01/dyn/thr"].waitForExistence(timeout: 2))
    }

    func testDraggingOnTheGraphMovesTheGrabbedBand() {
        launch()
        open("Kick")
        app.buttons["EQ"].tap()
        let frequency = app.descendants(matching: .any)["/ch/01/eq/1/f"]
        let gain = app.descendants(matching: .any)["/ch/01/eq/1/g"]
        XCTAssertTrue(frequency.waitForExistence(timeout: 2))
        XCTAssertEqual(frequency.value as? String, "632 Hz")
        let graph = app.descendants(matching: .any)["eq-graph"]

        // All fake bands sit at the centre point; the nearest-band tie goes to band 1.
        graph.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo: graph.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.25)))

        XCTAssertNotEqual(frequency.value as? String, "632 Hz")
        XCTAssertNotEqual(gain.value as? String, "0.0 dB")
        saveScreenshot("task-15-eq")
    }

    // The EQ tests below each use their own channel: the fake keeps every edit, and Kick's EQ is
    // expected untouched by the drag test above.

    /// A touch near a band point grabs it, but only movement moves it: landing slightly off the point
    /// must not jump the desk to where the finger happens to be.
    func testTouchingNearABandChangesNothing() {
        launch()
        open("Tom 2")
        app.buttons["EQ"].tap()
        let frequency = app.descendants(matching: .any)["/ch/05/eq/1/f"]
        let gain = app.descendants(matching: .any)["/ch/05/eq/1/g"]
        XCTAssertTrue(frequency.waitForExistence(timeout: 2))
        let graph = app.descendants(matching: .any)["eq-graph"]
        let nearTheCentrePoint = graph.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 20, dy: -25))
        nearTheCentrePoint.press(forDuration: 0.3)
        XCTAssertEqual(frequency.value as? String, "632 Hz")
        XCTAssertEqual(gain.value as? String, "0.0 dB")
    }

    func testEQTabScrollsAsAWhole() {
        launch()
        open("Tom 1")
        app.buttons["EQ"].tap()
        let graph = app.descendants(matching: .any)["eq-graph"]
        XCTAssertTrue(graph.waitForExistence(timeout: 2))
        let top = graph.frame.minY
        // Drag from the Type row: on a 375 pt phone the rows below it start at the screen's bottom edge.
        let type = app.buttons["/ch/04/eq/1/type"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        type.press(forDuration: 0.05, thenDragTo: type.withOffset(CGVector(dx: 0, dy: -250)))
        XCTAssertLessThan(graph.frame.minY, top)
        saveScreenshot("eq-scrolled")
    }

    func testBandTypeIsADropdown() {
        launch()
        open("Tom 1")
        app.buttons["EQ"].tap()
        let type = app.buttons["/ch/04/eq/1/type"]
        XCTAssertTrue(type.waitForExistence(timeout: 2))
        XCTAssertEqual(type.value as? String, "PEQ")
        type.tap()
        app.buttons["LShv"].tap()
        XCTAssertEqual(type.value as? String, "LShv")
    }

    func testResetBandsAsksFirst() {
        launch()
        open("Snare")
        app.buttons["EQ"].tap()
        let frequency = app.descendants(matching: .any)["/ch/02/eq/1/f"]
        XCTAssertTrue(frequency.waitForExistence(timeout: 2))
        XCTAssertEqual(frequency.value as? String, "632 Hz")
        frequency.swipeUp()
        app.buttons["Reset bands"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(frequency.value as? String, "632 Hz")
        app.buttons["Reset bands"].tap()
        app.buttons["Reset all 4 bands"].tap()
        XCTAssertEqual(frequency.value as? String, "91.4 Hz")
    }

    func testDoubleTappingABandResetsIt() {
        launch()
        open("Hi-hat")
        app.buttons["EQ"].tap()
        let frequency = app.descendants(matching: .any)["/ch/03/eq/1/f"]
        XCTAssertTrue(frequency.waitForExistence(timeout: 2))
        XCTAssertEqual(frequency.value as? String, "632 Hz")
        // All fake bands sit at the centre point; the nearest-band tie goes to band 1.
        app.descendants(matching: .any)["eq-graph"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .doubleTap()
        XCTAssertEqual(frequency.value as? String, "91.4 Hz")
    }

    func testBusEQHasSixBands() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        XCTAssertTrue(app.buttons["6"].waitForExistence(timeout: 2))
    }

    func testSendsListBusesByName() {
        launch()
        open("Vox 1")
        app.buttons["Sends"].tap()
        let toMon1 = app.descendants(matching: .any)["/ch/13/mix/01/level"]
        XCTAssertTrue(toMon1.waitForExistence(timeout: 2))
        XCTAssertEqual(toMon1.label, "Mon 1")
        XCTAssertEqual(toMon1.value as? String, "0.0 dB")
    }

    func testFedByShowsWhoFeedsTheBus() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        app.buttons["Fed by"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["/ch/13/mix/01/level"].waitForExistence(timeout: 2))
        XCTAssertEqual(
            app.descendants(matching: .any)["/ch/13/mix/01/level"].value as? String, "0.0 dB")
        XCTAssertTrue(app.descendants(matching: .any)["/fxrtn/01/mix/01/level"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["/ch/20/mix/01/level"].exists)
        saveScreenshot("task-16-fedby")
    }
}

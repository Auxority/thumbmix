import XCTest

/// A band's rows: their double-tap resets, and Gain and Q on a cut filter.
@MainActor
final class EQBandUITests: DeskUITestCase {
    /// Moving a band mid-show can howl, so a row's reset asks first, like Reset bands.
    func testDoubleTappingFrequencyAsksThenRestoresTheDefault() {
        launch()
        open("Kick")
        app.buttons["EQ"].tap()
        let frequency = app.descendants(matching: .any)["/ch/01/eq/1/f"]
        XCTAssertTrue(frequency.appears(within: 2))
        XCTAssertEqual(frequency.value as? String, "632 Hz")
        frequency.doubleTap()
        let alert = app.alerts["Reset the frequency to 91.4 Hz?"]
        XCTAssertTrue(alert.appears(within: 2))
        alert.buttons["Reset"].tap()
        XCTAssertTrue(eventually(within: 2) { frequency.value as? String == "91.4 Hz" })
    }

    func testBusResetsAllSixBands() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        app.buttons["EQ"].tap()
        let type = app.buttons["/bus/01/eq/1/type"]
        XCTAssertTrue(type.appears(within: 2))
        // Drag from the Type row: on a 375 pt phone the rows below it start past the screen's bottom edge.
        let start = type.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -300)))
        app.buttons["Reset bands"].tap()
        let alert = app.alerts["Reset all 6 bands of Mon 1?"]
        XCTAssertTrue(alert.appears(within: 2))
        alert.buttons["Reset"].tap()
        let frequency = app.descendants(matching: .any)["/bus/01/eq/1/f"]
        XCTAssertTrue(eventually(within: 2) { frequency.value as? String == "54.5 Hz" })
    }

    /// A cut filter has no level to shape: its Gain and Q rows stay in place but take no edits.
    func testCutFilterDisablesGainAndQ() {
        launch()
        open("Tom 2")
        app.buttons["EQ"].tap()
        let type = app.buttons["/ch/05/eq/1/type"]
        let gain = app.descendants(matching: .any)["/ch/05/eq/1/g"]
        let q = app.descendants(matching: .any)["/ch/05/eq/1/q"]
        XCTAssertTrue(type.appears(within: 2))
        XCTAssertTrue(gain.isEnabled)
        type.tap()
        app.buttons["LCut"].tap()
        XCTAssertTrue(eventually(within: 2) { !gain.isEnabled && !q.isEnabled })
        let before = gain.frame
        gain.doubleTap()
        XCTAssertEqual(app.alerts.count, 0, "a disabled row doesn't offer a reset")
        XCTAssertEqual(gain.frame, before, "the rows stay where they were")
        saveScreenshot("eq-cut-band")
    }
}

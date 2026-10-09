import XCTest

/// The Input tab's delay (mock C: below Trim, in ms and distance) and its double-tap resets.
@MainActor
final class InputUITests: DeskUITestCase {
    private func openKicksInput() {
        launch()
        open("Kick")
        app.buttons["Input"].tap()
    }

    /// The demo desk starts with delay off at 0.3 ms; the UI tests run in en_US, so the distance reads in feet.
    func testDelaySitsBelowTrimInTimeAndDistance() {
        openKicksInput()
        let on = element("toggle-/ch/01/delay/on")
        let time = element("/ch/01/delay/time")
        XCTAssertTrue(time.appears(within: 2))
        XCTAssertGreaterThan(time.frame.minY, element("/ch/01/preamp/trim").frame.maxY, "below Trim")
        XCTAssertEqual(time.value as? String, "0.30 ms · 0.3 ft")
        XCTAssertEqual(on.value as? String, "Off")
        on.tap()
        XCTAssertTrue(eventually(within: 2) { on.value as? String == "On" })
        saveScreenshot("input-delay")
    }

    /// Like every double-tap in the app: the reset goes at once.
    func testDoubleTapResetsTheDelayAtOnce() {
        openKicksInput()
        let time = element("/ch/01/delay/time")
        XCTAssertTrue(time.appears(within: 2))
        time.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: time.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
        XCTAssertNotEqual(time.value as? String, "0.30 ms · 0.3 ft")
        time.doubleTap()
        XCTAssertTrue(eventually(within: 2) { time.value as? String == "0.30 ms · 0.3 ft" })
        XCTAssertEqual(app.alerts.count, 0)
    }

    func testDoubleTapResetsThePreampGainAtOnce() {
        openKicksInput()
        let gain = element("/headamp/032/gain")
        XCTAssertTrue(gain.appears(within: 2))
        XCTAssertEqual(gain.value as? String, "+24.0 dB")
        gain.doubleTap()
        XCTAssertTrue(eventually(within: 2) { gain.value as? String == "0.0 dB" })
        XCTAssertEqual(app.alerts.count, 0)
    }

    /// The slim fader row above the tab already meters the channel, so Gain comes right under it.
    func testGainSitsRightUnderTheFaderRow() {
        openKicksInput()
        let gain = element("/headamp/032/gain")
        XCTAssertTrue(gain.appears(within: 2))
        let gap = gain.frame.minY - element("/ch/01/mix/fader").frame.maxY
        XCTAssertLessThanOrEqual(gap, 13, "no meter between the fader row and Gain")
    }
}

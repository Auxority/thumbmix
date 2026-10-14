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

    /// The safety rule: a chip shows nothing the desk didn't send. Unread, it waits disabled rather than claim "Off".
    func testAChipWaitsUntilItsValueIsRead() {
        desk.forget("/ch/01/delay/on")
        openKicksInput()
        let on = element("toggle-/ch/01/delay/on")
        let time = element("/ch/01/delay/time")
        XCTAssertTrue(eventually(within: 3) { time.value as? String == "0.30 ms · 0.3 ft" }, "the tab was read")
        XCTAssertFalse(on.isEnabled)
        XCTAssertNotEqual(on.value as? String, "Off", "VoiceOver claims nothing either")
        saveScreenshot("input-delay-unread")
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

    /// Ø beside Trim, like 48V beside Gain (mock A, 2026-10-12). It asks first, and the alert explains polarity.
    func testPolarityAsksAndExplainsBeforeFlipping() {
        openKicksInput()
        let flip = app.buttons["toggle-/ch/01/preamp/invert"]
        XCTAssertTrue(flip.appears(within: 2))
        XCTAssertEqual(flip.value as? String, "Normal")
        XCTAssertEqual(flip.frame.midY, element("/ch/01/preamp/trim").frame.midY, accuracy: 2, "beside Trim")

        flip.tap()
        let alert = app.alerts["Flip the polarity of Kick?"]
        XCTAssertTrue(alert.appears(within: 2))
        let explanation = "Turns the signal upside down. Try it when two mics on one source sound thin together."
        XCTAssertTrue(alert.staticTexts[explanation].exists)
        saveScreenshot("polarity-alert")
        alert.buttons["Flip"].tap()
        XCTAssertTrue(eventually(within: 2) { flip.value as? String == "Flipped" })
        saveScreenshot("polarity-flipped")

        flip.tap()
        let back = app.alerts["Set Kick's polarity back to normal?"]
        XCTAssertTrue(back.appears(within: 2))
        back.buttons["Normal"].tap()
        XCTAssertTrue(eventually(within: 2) { flip.value as? String == "Normal" })
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

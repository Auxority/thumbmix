import XCTest

/// The Input tab's delay (mock C: below Trim, in ms and distance) and the resets that ask first.
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

    /// A double-tap is as easy to hit by accident as a drag, so the delay's reset asks first.
    func testResettingTheDelayAsksFirst() {
        openKicksInput()
        let time = element("/ch/01/delay/time")
        XCTAssertTrue(time.appears(within: 2))
        time.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: time.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
        let moved = time.value as? String
        XCTAssertNotEqual(moved, "0.30 ms · 0.3 ft")

        time.doubleTap()
        let alert = app.alerts["Reset the delay to 0.3 ms?"]
        XCTAssertTrue(alert.appears(within: 2))
        alert.buttons["Cancel"].tap()
        XCTAssertEqual(time.value as? String, moved, "Cancel leaves the delay as it was")

        time.doubleTap()
        alert.buttons["Reset"].tap()
        XCTAssertTrue(eventually(within: 2) { time.value as? String == "0.30 ms · 0.3 ft" })
    }

    /// A reset reaches more than the channel on screen: the alert names the linked partner (Gtr L/R, Gain/Delay
    /// linked) and channels on the same input (Vox 1 and 2), like the 48V alert.
    func testResetPromptsNameEveryChannelTheyReach() {
        launch()
        app.swipeUp()
        app.buttons["Gtr"].tap()
        XCTAssertTrue(app.buttons["+1 dB"].appears(within: 3))
        app.buttons["Input"].tap()
        XCTAssertTrue(element("/headamp/040/gain").appears(within: 2), "Gtr gain row")
        element("/headamp/040/gain").doubleTap()
        let gainAlert = app.alerts["Reset the preamp gain to 0 dB?"]
        XCTAssertTrue(gainAlert.appears(within: 2), "Gtr gain alert")
        XCTAssertTrue(gainAlert.staticTexts["Also resets Gtr R (linked)."].exists, "Gtr gain partner line")
        gainAlert.buttons["Cancel"].tap()
        element("/ch/09/delay/time").doubleTap()
        let delayAlert = app.alerts["Reset the delay to 0.3 ms?"]
        XCTAssertTrue(delayAlert.appears(within: 2), "Gtr delay alert")
        XCTAssertTrue(delayAlert.staticTexts["Also resets Gtr R (linked)."].exists, "Gtr delay partner line")
        delayAlert.buttons["Cancel"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeDown()
        open("Vox 2")
        app.buttons["Input"].tap()
        XCTAssertTrue(element("/headamp/044/gain").appears(within: 2), "Vox 2 gain row")
        element("/headamp/044/gain").doubleTap()
        let voxAlert = app.alerts["Reset the preamp gain to 0 dB?"]
        XCTAssertTrue(voxAlert.appears(within: 2), "Vox 2 gain alert")
        XCTAssertTrue(voxAlert.staticTexts["Also resets Vox 1 (same input)."].exists, "Vox 2 same-input line")
        voxAlert.buttons["Cancel"].tap()
    }

    /// Preamp gain resets to 0 dB, after asking: a jump in gain can cause feedback.
    func testResettingThePreampGainAsksFirst() {
        openKicksInput()
        let gain = element("/headamp/032/gain")
        XCTAssertTrue(gain.appears(within: 2))
        XCTAssertEqual(gain.value as? String, "+24.0 dB")
        gain.doubleTap()
        let alert = app.alerts["Reset the preamp gain to 0 dB?"]
        XCTAssertTrue(alert.appears(within: 2))
        alert.buttons["Cancel"].tap()
        XCTAssertEqual(gain.value as? String, "+24.0 dB")
        gain.doubleTap()
        alert.buttons["Reset"].tap()
        XCTAssertTrue(eventually(within: 2) { gain.value as? String == "0.0 dB" })
    }
}

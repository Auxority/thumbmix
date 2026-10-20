import XCTest

/// The Input tab: Gain under the fader row, Ø beside Trim, the delay below it (mock C: in ms and distance).
@MainActor
final class InputUITests: DeskUITestCase {
    /// The slim fader row above the tab already meters the channel, so Gain comes right under it. Ø sits beside Trim,
    /// like 48V beside Gain (mock A, 2026-10-12), asks first and explains polarity. The demo desk starts with delay off
    /// at 0.3 ms; the UI tests run in en_US, so the distance reads in feet.
    func testTheInputTabFlipsPolarityAndSwitchesTheDelay() {
        launchAndOpen("Kick", tab: "Input")
        let gain = element("/headamp/032/gain")
        XCTAssertTrue(gain.appears(within: 2))
        let gap = gain.frame.minY - element("/ch/01/mix/fader").frame.maxY
        XCTAssertLessThanOrEqual(gap, 13, "no meter between the fader row and Gain")

        let trim = element("/ch/01/preamp/trim")
        let flip = app.buttons["toggle-/ch/01/preamp/invert"]
        XCTAssertEqual(flip.value as? String, "Normal")
        XCTAssertEqual(flip.frame.midY, trim.frame.midY, accuracy: 2, "Ø beside Trim")
        flip.tap()
        let alert = app.alerts["Flip the polarity of Kick?"]
        XCTAssertTrue(alert.appears(within: 2))
        let explanation = "Turns the signal upside down. Try it when two mics on one source sound thin together."
        XCTAssertTrue(alert.staticTexts[explanation].exists)
        saveScreenshot("polarity-alert")
        alert.buttons["Flip"].tap()
        XCTAssertTrue(eventually(within: 2) { flip.value as? String == "Flipped" })
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/preamp/invert") == .int(1) }, "flipped on the desk")
        saveScreenshot("polarity-flipped")
        Thread.sleep(forTimeInterval: 0.4)
        flip.tap()
        let back = app.alerts["Set Kick's polarity back to normal?"]
        XCTAssertTrue(back.appears(within: 2))
        back.buttons["Normal"].tap()
        XCTAssertTrue(eventually(within: 2) { flip.value as? String == "Normal" })
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/preamp/invert") == .int(0) }, "normal on the desk")

        let on = element("toggle-/ch/01/delay/on")
        let time = element("/ch/01/delay/time")
        XCTAssertGreaterThan(time.frame.minY, trim.frame.maxY, "the delay below Trim")
        XCTAssertEqual(time.value as? String, "0.30 ms · 0.3 ft")
        XCTAssertEqual(on.value as? String, "Off")
        on.tap()
        XCTAssertTrue(eventually(within: 2) { on.value as? String == "On" })
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/delay/on") == .int(1) }, "on at the desk")
        saveScreenshot("input-delay")
    }

    /// The safety rule: a chip shows nothing the desk didn't send. Unread, it waits disabled rather than claim "Off".
    func testAChipWaitsUntilItsValueIsRead() {
        desk.forget("/ch/01/delay/on")
        launchAndOpen("Kick", tab: "Input")
        let on = element("toggle-/ch/01/delay/on")
        let time = element("/ch/01/delay/time")
        XCTAssertTrue(eventually(within: 3) { time.value as? String == "0.30 ms · 0.3 ft" }, "the tab was read")
        XCTAssertFalse(on.isEnabled)
        XCTAssertNotEqual(on.value as? String, "Off", "VoiceOver claims nothing either")
        saveScreenshot("input-delay-unread")
    }
}

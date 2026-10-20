import XCTest

@MainActor
final class ChannelUITests: DeskUITestCase {
    /// Mix tab, top to bottom: fader, then SOLO | MUTE. The ±1 dB buttons went (2026-10-17): holding the fader types
    /// a value. SOLO reaches the desk's solo switch. The tabs sit under the thumb, each at least Apple's 44 pt touch
    /// target. Every other tab keeps a slim fader with S and M (mock T2), to pull or solo a channel mid-EQ.
    func testSoloSitsBesideMuteRightBelowTheFader() {
        launchAndOpen("Kick")
        let solo = element("solo-/-stat/solosw/01")
        XCTAssertTrue(solo.appears(within: 2))
        let mute = element("mute-/ch/01/mix/on")
        let fader = element("/ch/01/mix/fader")
        XCTAssertFalse(app.buttons["+1 dB"].exists, "no nudge buttons")
        XCTAssertGreaterThan(solo.frame.minY, fader.frame.maxY, "SOLO below the fader")
        XCTAssertEqual(solo.frame.midY, mute.frame.midY, accuracy: 1, "SOLO and MUTE share a row")
        XCTAssertEqual(solo.label, "Solo Kick")
        solo.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/-stat/solosw/01") == .int(1) })
        XCTAssertEqual(solo.label, "Unsolo Kick")
        saveScreenshot("mix-solo")

        let screenHeight = app.windows.firstMatch.frame.height
        for title in ["Mix", "Input", "Gate", "EQ", "Comp", "Sends"] {
            XCTAssertGreaterThan(app.buttons[title].frame.minY, screenHeight * 0.8, "\(title) sits under the thumb")
        }

        app.buttons["EQ"].tap()
        let slimSolo = app.buttons["solo-/-stat/solosw/01"]
        XCTAssertTrue(slimSolo.appears(within: 2))
        XCTAssertGreaterThan(slimSolo.frame.minX, fader.frame.maxX, "S right of the slim fader")
        XCTAssertGreaterThan(app.buttons["mute-/ch/01/mix/on"].frame.minX, slimSolo.frame.maxX, "M right of S")
        slimSolo.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/-stat/solosw/01") == .int(0) }, "unsoloed mid-EQ")
        saveScreenshot("slim-mix-row")
    }

    /// The engineer sets both on a preamp channel: Gain and 48V for the preamp, Trim for the channel. 48V sits beside
    /// Gain like MUTE beside a fader, and every switch asks first: phantom power can harm a mic. Ends switched off
    /// again, as the demo desk started.
    func testPhantomPowerAsksBeforeSwitching() {
        launchAndOpen("Vox 2", tab: "Input")
        let phantom = app.buttons["toggle-/headamp/044/phantom"]
        let gain = element("/headamp/044/gain")
        XCTAssertTrue(phantom.appears(within: 2))
        XCTAssertTrue(app.staticTexts["Shares an input with Vox 1"].exists)
        XCTAssertTrue(element("/ch/14/preamp/trim").exists, "Trim for the channel")
        saveScreenshot("task-13-input")
        XCTAssertEqual(phantom.value as? String, "Off")
        XCTAssertEqual(phantom.frame.midY, gain.frame.midY, accuracy: 2, "beside the Gain row")

        phantom.tap()
        let turnOn = app.alerts["Turn on 48V for Vox 2?"]
        XCTAssertTrue(turnOn.appears(within: 2))
        XCTAssertTrue(turnOn.staticTexts["Also powers Vox 1 (same input)."].exists)
        saveScreenshot("phantom-alert")
        turnOn.buttons["Cancel"].tap()
        XCTAssertEqual(phantom.value as? String, "Off", "Cancel leaves the desk as it was")
        XCTAssertEqual(desk.value("/headamp/044/phantom"), .int(0))

        Thread.sleep(forTimeInterval: 0.4)
        phantom.tap()
        turnOn.buttons["Turn On"].tap()
        XCTAssertTrue(eventually(within: 2) { phantom.value as? String == "On" })
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/headamp/044/phantom") == .int(1) }, "on at the desk")
        saveScreenshot("phantom-on")

        phantom.tap()
        let turnOff = app.alerts["Turn off 48V for Vox 2?"]
        XCTAssertTrue(turnOff.appears(within: 2))
        turnOff.buttons["Turn Off"].tap()
        XCTAssertTrue(eventually(within: 2) { phantom.value as? String == "Off" })
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/headamp/044/phantom") == .int(0) }, "off at the desk")
    }
}

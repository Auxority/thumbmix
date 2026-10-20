import XCTest

@MainActor
final class ChannelUITests: DeskUITestCase {
    /// Mix tab, top to bottom: fader, then SOLO | MUTE. The ±1 dB buttons went (2026-10-17): holding the fader types
    /// a value. SOLO reaches the desk's solo switch.
    func testSoloSitsBesideMuteRightBelowTheFader() {
        launchAndOpen("Kick")
        let solo = element("solo-/-stat/solosw/01")
        XCTAssertTrue(solo.appears(within: 2))
        let mute = element("mute-/ch/01/mix/on")
        let fader = element("/ch/01/mix/fader")
        XCTAssertFalse(app.buttons["+1 dB"].exists, "no nudge buttons")
        XCTAssertEqual(solo.frame.minY - fader.frame.maxY, 10, accuracy: 2, "SOLO right below the fader")
        XCTAssertEqual(solo.frame.midY, mute.frame.midY, accuracy: 1, "SOLO and MUTE share a row")
        XCTAssertLessThan(solo.frame.minX, mute.frame.minX, "SOLO left of MUTE")
        XCTAssertEqual(solo.label, "Solo Kick")
        solo.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/-stat/solosw/01") == .int(1) })
        XCTAssertEqual(solo.label, "Unsolo Kick")
        saveScreenshot("mix-solo")
    }

    /// Mix holds the full controls; every other tab keeps a slim fader with S and M (mock T2), to pull or solo a
    /// channel mid-EQ.
    func testOtherTabsKeepTheFaderSoloAndMuteInReach() {
        launchAndOpen("Kick", tab: "EQ")
        let fader = element("/ch/01/mix/fader")
        XCTAssertTrue(fader.exists)
        let solo = app.buttons["solo-/-stat/solosw/01"]
        let mute = app.buttons["mute-/ch/01/mix/on"]
        XCTAssertTrue(solo.exists)
        XCTAssertTrue(mute.exists)
        XCTAssertGreaterThan(solo.frame.minX, fader.frame.maxX, "S right of the fader")
        XCTAssertGreaterThan(mute.frame.minX, solo.frame.maxX, "M right of S")
        XCTAssertEqual(solo.label, "Solo Kick")
        solo.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/-stat/solosw/01") == .int(1) })
        saveScreenshot("slim-mix-row")
    }

    /// The tabs sit under the thumb, each at least Apple's 44 pt touch target.
    func testTabsSitAtTheBottomWithFullSizeTargets() {
        launchAndOpen("Kick")
        let screenHeight = app.windows.firstMatch.frame.height
        for title in ["Mix", "Input", "Gate", "EQ", "Comp", "Sends"] {
            let tab = app.buttons[title].frame
            XCTAssertGreaterThanOrEqual(tab.height, 44, title)
            XCTAssertGreaterThanOrEqual(tab.width, 44, title)
            XCTAssertGreaterThan(tab.minY, screenHeight * 0.8, title)
        }
    }

    /// The engineer sets both on a preamp channel: Gain and 48V for the preamp, Trim for the channel.
    func testPreampChannelShowsGainAndTrim() {
        launchAndOpen("Vox 2", tab: "Input")
        XCTAssertTrue(app.descendants(matching: .any)["/headamp/044/gain"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["toggle-/headamp/044/phantom"].exists)
        XCTAssertTrue(app.staticTexts["Shares an input with Vox 1"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["/ch/14/preamp/trim"].exists)
        saveScreenshot("task-13-input")
    }

    /// 48V sits beside Gain like MUTE beside a fader, and every switch asks first: phantom power can harm a mic.
    /// Ends switched off again, as the demo desk started.
    func testPhantomPowerAsksBeforeSwitching() {
        launchAndOpen("Vox 2", tab: "Input")
        let phantom = app.buttons["toggle-/headamp/044/phantom"]
        let gain = app.descendants(matching: .any)["/headamp/044/gain"]
        XCTAssertTrue(phantom.appears(within: 2))
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

    func testInternalSourceShowsTrimNotGain() {
        launch()
        app.swipeUp()
        open("Ch 15")
        app.buttons["Input"].tap()
        XCTAssertTrue(
            app.staticTexts["No preamp: this channel reads from an internal source."].appears(within: 3))
        XCTAssertTrue(app.descendants(matching: .any)["/ch/15/preamp/trim"].exists)
        let headampControls = NSPredicate(format: "identifier CONTAINS '/headamp/'")
        XCTAssertEqual(app.descendants(matching: .any).matching(headampControls).count, 0)
    }
}

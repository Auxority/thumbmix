import XCTest

@MainActor
final class ChannelUITests: DeskUITestCase {
    func testNudgeButtonsMoveOneDecibel() {
        launchAndOpen("Kick")
        let fader = app.descendants(matching: .any)["/ch/01/mix/fader"]
        XCTAssertEqual(fader.value as? String, "0.0 dB")
        app.buttons["+1 dB"].tap()
        XCTAssertEqual(fader.value as? String, "+1.0 dB")
        app.buttons["−1 dB"].tap()
        XCTAssertEqual(fader.value as? String, "0.0 dB")
        // The grid's rounding used to pile up: by the third tap the fader showed −3.1 dB.
        for _ in 1...5 { app.buttons["−1 dB"].tap() }
        XCTAssertEqual(fader.value as? String, "−5.0 dB")
    }

    /// Mix tab, top to bottom (notes 2026-10-13): fader, −1 | +1, SOLO | MUTE. SOLO reaches the desk's solo switch.
    func testSoloSitsBesideMuteBelowTheNudges() {
        launchAndOpen("Kick")
        let solo = element("solo-/-stat/solosw/01")
        XCTAssertTrue(solo.appears(within: 2))
        let mute = element("mute-/ch/01/mix/on")
        let plusOne = app.buttons["+1 dB"]
        XCTAssertGreaterThan(solo.frame.minY, plusOne.frame.maxY, "SOLO below the nudges")
        XCTAssertEqual(solo.frame.midY, mute.frame.midY, accuracy: 1, "SOLO and MUTE share a row")
        XCTAssertLessThan(solo.frame.minX, mute.frame.minX, "SOLO left of MUTE")
        XCTAssertEqual(solo.label, "Solo Kick")
        solo.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/-stat/solosw/01") == .int(1) })
        XCTAssertEqual(solo.label, "Unsolo Kick")
        saveScreenshot("mix-solo")
    }

    /// Held, a nudge keeps stepping 1 dB (mock A): a one-second hold moves several dB, still on whole steps.
    func testHoldingANudgeRepeats() {
        launchAndOpen("Kick")
        let fader = element("/ch/01/mix/fader")
        XCTAssertEqual(fader.value as? String, "0.0 dB")
        app.buttons["+1 dB"].press(forDuration: 1.2)
        let shown = fader.value as? String ?? ""
        let decibels = Double(shown.replacingOccurrences(of: " dB", with: "").replacingOccurrences(of: "+", with: ""))
        XCTAssertGreaterThanOrEqual(decibels ?? 0, 3, "a 1.2 s hold should repeat, shows \(shown)")
        XCTAssertTrue(shown.hasSuffix(".0 dB"), "steps stay whole from 0 dB, shows \(shown)")
    }

    /// A finger that slides off a held nudge stops it, like any button: the fader must not keep climbing.
    func testSlidingOffAHeldNudgeStopsIt() {
        launchAndOpen("Kick")
        let fader = element("/ch/01/mix/fader")
        app.buttons["+1 dB"].press(
            forDuration: 0.1, thenDragTo: app.staticTexts["Kick"], withVelocity: .fast, thenHoldForDuration: 1.5)
        XCTAssertEqual(fader.value as? String, "+1.0 dB")
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
        XCTAssertFalse(app.buttons["+1 dB"].exists, "the nudges live on the Mix tab")
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

        phantom.tap()
        turnOn.buttons["Turn On"].tap()
        XCTAssertTrue(eventually(within: 2) { phantom.value as? String == "On" })
        saveScreenshot("phantom-on")

        phantom.tap()
        let turnOff = app.alerts["Turn off 48V for Vox 2?"]
        XCTAssertTrue(turnOff.appears(within: 2))
        turnOff.buttons["Turn Off"].tap()
        XCTAssertTrue(eventually(within: 2) { phantom.value as? String == "Off" })
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

import XCTest

@MainActor
final class ChannelUITests: DeskUITestCase {
    func testNudgeButtonsMoveOneDecibel() {
        launch()
        open("Kick")
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

    /// Held, a nudge keeps stepping 1 dB (mock A): a one-second hold moves several dB, still on whole steps.
    func testHoldingANudgeRepeats() {
        launch()
        open("Kick")
        let fader = element("/ch/01/mix/fader")
        XCTAssertEqual(fader.value as? String, "0.0 dB")
        app.buttons["+1 dB"].press(forDuration: 1.2)
        let shown = fader.value as? String ?? ""
        let decibels = Double(shown.replacingOccurrences(of: " dB", with: "").replacingOccurrences(of: "+", with: ""))
        XCTAssertGreaterThanOrEqual(decibels ?? 0, 3, "a 1.2 s hold should repeat, shows \(shown)")
        XCTAssertTrue(shown.hasSuffix(".0 dB"), "steps stay whole from 0 dB, shows \(shown)")
    }

    /// Mix holds the full controls; every other tab keeps a slim fader and mute, to pull a channel mid-EQ.
    func testOtherTabsKeepTheFaderAndMuteInReach() {
        launch()
        open("Kick")
        app.buttons["EQ"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["/ch/01/mix/fader"].exists)
        XCTAssertTrue(app.buttons["mute-/ch/01/mix/on"].exists)
        XCTAssertFalse(app.buttons["+1 dB"].exists, "the nudges live on the Mix tab")
        saveScreenshot("slim-mix-row")
    }

    /// The tabs sit under the thumb, each at least Apple's 44 pt touch target.
    func testTabsSitAtTheBottomWithFullSizeTargets() {
        launch()
        open("Kick")
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
        launch()
        open("Vox 2")
        app.buttons["Input"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["/headamp/044/gain"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["toggle-/headamp/044/phantom"].exists)
        XCTAssertTrue(app.staticTexts["Shares an input with Vox 1"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["/ch/14/preamp/trim"].exists)
        saveScreenshot("task-13-input")
    }

    /// 48V sits beside Gain like MUTE beside a fader, and every switch asks first: phantom power can harm a mic.
    /// Ends switched off again, as the demo desk started.
    func testPhantomPowerAsksBeforeSwitching() {
        launch()
        open("Vox 2")
        app.buttons["Input"].tap()
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
        app.buttons["Unused"].tap()
        app.swipeUp()
        open("Ch 15")
        app.buttons["Input"].tap()
        XCTAssertTrue(
            app.staticTexts["No preamp: this channel reads from an internal source."].appears(within: 3))
        XCTAssertTrue(app.descendants(matching: .any)["/ch/15/preamp/trim"].exists)
        let headampControls = NSPredicate(format: "identifier CONTAINS '/headamp/'")
        XCTAssertEqual(app.descendants(matching: .any).matching(headampControls).count, 0)
    }

    func testRenamingADCAReachesTheOverview() {
        launch()
        app.buttons["DCA"].tap()
        open("Band")
        app.buttons["edit-strip"].tap()
        let field = app.textFields["strip-name"]
        XCTAssertTrue(field.appears(within: 3))
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
        XCTAssertTrue(app.staticTexts["Rhythm secti"].appears(within: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Rhythm secti"].appears(within: 3))
    }

    func testCancelLeavesTheDeskUnchanged() {
        launch()
        app.buttons["DCA"].tap()
        open("Vox")
        app.buttons["edit-strip"].tap()
        let field = app.textFields["strip-name"]
        XCTAssertTrue(field.appears(within: 3))
        field.tap()
        field.typeText("X")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Vox"].appears(within: 3))
        XCTAssertFalse(app.staticTexts["VoxX"].exists)
    }

    func testDCAMembers() {
        launch()
        app.buttons["DCA"].tap()
        open("Drums")
        app.buttons["Members"].tap()
        XCTAssertTrue(app.staticTexts["Snare"].exists)
        XCTAssertFalse(app.staticTexts["Bass"].exists)
    }

    func testSendsListBusesByName() {
        launch()
        open("Vox 1")
        app.buttons["Sends"].tap()
        let toMon1 = app.descendants(matching: .any)["/ch/13/mix/01/level"]
        XCTAssertTrue(toMon1.appears(within: 2))
        XCTAssertEqual(toMon1.label, "Mon 1")
        XCTAssertEqual(toMon1.value as? String, "0.0 dB")
    }

    func testFedByShowsWhoFeedsTheBus() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        app.buttons["Fed by"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["/ch/13/mix/01/level"].appears(within: 2))
        XCTAssertEqual(
            app.descendants(matching: .any)["/ch/13/mix/01/level"].value as? String, "0.0 dB")
        XCTAssertTrue(app.descendants(matching: .any)["/fxrtn/01/mix/01/level"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["/ch/20/mix/01/level"].exists)
        saveScreenshot("task-16-fedby")
    }

    /// A matrix is fed by the buses and the mains; the demo's Fill takes the main mix at 0 dB.
    func testMatrixIsFedByTheMains() {
        launch()
        // The last chip sits past the edge of a 375 pt screen: the engineer swipes the chip row first.
        app.buttons["Buses"].swipeLeft()
        app.buttons["Matrix"].tap()
        open("Fill")
        app.buttons["Fed by"].tap()
        let fromMain = element("/main/st/mix/01/level")
        XCTAssertTrue(fromMain.appears(within: 2))
        XCTAssertEqual(fromMain.label, "LR")
        XCTAssertEqual(fromMain.value as? String, "0.0 dB")
        XCTAssertTrue(element("/bus/01/mix/01/level").exists)
        XCTAssertFalse(element("/ch/01/mix/01/level").exists, "inputs feed buses, not matrices")
        saveScreenshot("matrix-fedby")
    }
}

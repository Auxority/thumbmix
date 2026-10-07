import XCTest

/// The demo desk links Gtr L/R (ch 9-10) with every Link Preference ticked.
@MainActor
final class PairUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func launchAndOpenGuitars() {
        app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", "127.0.0.1"] + fixedLocale
        app.launch()
        XCTAssertTrue(app.buttons["Kick"].waitForExistence(timeout: 15))
        app.swipeUp()
        app.buttons["Gtr"].tap()
        XCTAssertTrue(app.buttons["+1 dB"].waitForExistence(timeout: 3))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// One fader and mute for both sides, but the desk keeps a pan per side.
    func testAPairOpensAsOneStereoStrip() {
        launchAndOpenGuitars()
        XCTAssertTrue(app.navigationBars["Ch 9-10"].exists)
        XCTAssertEqual(app.buttons["edit-strip"].value as? String, "Gtr")
        XCTAssertTrue(element("/ch/09/mix/fader").exists)
        XCTAssertFalse(element("/ch/10/mix/fader").exists)
        XCTAssertEqual(element("/ch/09/mix/pan").label, "Pan · Gtr L")
        XCTAssertEqual(element("/ch/10/mix/pan").label, "Pan · Gtr R")
        XCTAssertFalse(app.buttons["side-R"].exists)
        saveScreenshot("pair-mix")
        app.buttons["EQ"].tap()
        XCTAssertTrue(element("/ch/09/eq/1/f").waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["side-R"].exists, "the desk links the EQ")
    }

    /// Uses Mon 3 and Mon 4: the fake keeps every change, and no other test reads those buses.
    func testLinkAndUnlinkFromTheMixTab() {
        addTeardownBlock { DeskChange.set("/config/buslink/3-4", 0) }
        app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", "127.0.0.1"] + fixedLocale
        app.launch()
        XCTAssertTrue(app.buttons["Kick"].waitForExistence(timeout: 15))
        app.buttons["Buses"].tap()
        app.buttons["Mon 3"].tap()
        let link = app.buttons["link-button"]
        XCTAssertTrue(link.waitForExistence(timeout: 3))
        XCTAssertEqual(link.label, "Stereo link with Mon 4 · Bus 4")

        link.tap()
        let alert = app.alerts["Link Mon 3 and Mon 4?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.staticTexts["They'll work as one stereo channel."].exists)
        saveScreenshot("link-alert")
        alert.buttons["Link"].tap()
        XCTAssertTrue(app.navigationBars["Bus 3-4"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["edit-strip"].value as? String, "Mon")
        XCTAssertEqual(link.label, "Unlink Mon 3 · Bus 3 and Mon 4 · Bus 4")

        link.tap()
        let unlink = app.alerts["Unlink Mon 3 and Mon 4?"]
        XCTAssertTrue(unlink.waitForExistence(timeout: 2))
        XCTAssertTrue(unlink.staticTexts["Each can be set on its own again."].exists)
        unlink.buttons["Unlink"].tap()
        XCTAssertTrue(app.navigationBars["Bus 3"].waitForExistence(timeout: 3))
    }

    /// Linking only couples what the desk's Link Preferences tick: the alert says what stays separate.
    func testTheLinkAlertSaysWhatStaysSeparate() {
        DeskChange.set("/config/linkcfg/eq", 0)
        addTeardownBlock { DeskChange.set("/config/linkcfg/eq", 1) }
        app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", "127.0.0.1"] + fixedLocale
        app.launch()
        XCTAssertTrue(app.buttons["Kick"].waitForExistence(timeout: 15))
        app.buttons["Buses"].tap()
        app.buttons["Mon 3"].tap()
        app.buttons["link-button"].tap()
        let alert = app.alerts["Link Mon 3 and Mon 4?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.staticTexts["They'll work as one stereo channel.\nEQ stays separate."].exists)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Bus 3"].exists, "Cancel leaves the desk as it was")
    }

    /// Each side keeps its own name on the desk; the pair gets one colour and icon.
    func testEditStripNamesBothSides() {
        launchAndOpenGuitars()
        app.buttons["edit-strip"].tap()
        let left = app.textFields["strip-name"]
        XCTAssertTrue(left.waitForExistence(timeout: 3))
        XCTAssertEqual(left.value as? String, "Gtr L")
        XCTAssertEqual(app.textFields["strip-name-partner"].value as? String, "Gtr R")
        XCTAssertTrue(app.buttons["color-green"].exists)
        app.buttons["Cancel"].tap()
    }

    /// The engineer unticks Dynamics Link on the desk: Gate and Comp now show one side at a time.
    func testAnUnlinkedSectionShowsOneSideAtATime() {
        DeskChange.set("/config/linkcfg/dyn", 0)
        addTeardownBlock { DeskChange.set("/config/linkcfg/dyn", 1) }
        launchAndOpenGuitars()
        app.buttons["Comp"].tap()
        XCTAssertTrue(app.staticTexts["Dynamics aren't linked on the desk."].waitForExistence(timeout: 2))
        XCTAssertTrue(element("/ch/09/dyn/thr").exists)
        app.buttons["side-R"].tap()
        XCTAssertTrue(element("/ch/10/dyn/thr").waitForExistence(timeout: 2))
        XCTAssertFalse(element("/ch/09/dyn/thr").exists)
        saveScreenshot("pair-comp-unlinked")
        app.buttons["EQ"].tap()
        XCTAssertFalse(app.buttons["side-R"].exists, "the EQ is still linked")
    }
}

import ThumbmixCore
import XCTest

/// The demo desk links Gtr L/R (ch 9-10) with every Link Preference ticked.
@MainActor
final class PairUITests: DeskUITestCase {
    private func launchAndOpenGuitars() {
        launch()
        app.swipeUp()
        app.buttons["Gtr"].tap()
        XCTAssertTrue(app.buttons["Mix"].appears(within: 3))
    }

    /// A pair's Mix tab may scroll (two pans), but a fader drag that wanders vertically must stay a drag.
    private func aSlantedFaderDragDoesNotScrollThePage() {
        let fader = element("/ch/09/mix/fader")
        let before = fader.value as? String
        let top = fader.frame.minY
        fader.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3))
            .press(forDuration: 0.05, thenDragTo: fader.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.9)))
        XCTAssertTrue(eventually(within: 2) { fader.value as? String != before }, "the slanted drag moved the fader")
        XCTAssertEqual(fader.frame.minY, top, accuracy: 2, "the page scrolled")
    }

    /// A block count that flips while a linked edit settles mustn't resize the Insert sheet: it opens tall.
    private func theInsertSheetOpensTall() {
        app.buttons["insert-more"].tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.appears(within: 2))
        XCTAssertLessThan(done.frame.minY, app.frame.height / 3, "the Insert sheet opens large")
        done.tap()
    }

    /// One fader and mute for both sides, but the desk keeps a pan and a name per side. The linked EQ needs no side
    /// picker, and the linked preamp's alerts (48V, polarity: assumed, m32-probe 7e) name the partner they also switch.
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
        aSlantedFaderDragDoesNotScrollThePage()
        theInsertSheetOpensTall()

        app.buttons["edit-strip"].tap()
        let left = app.textFields["strip-name"]
        XCTAssertTrue(left.appears(within: 3))
        XCTAssertEqual(left.value as? String, "Gtr L", "each side keeps its own name")
        XCTAssertEqual(app.textFields["strip-name-partner"].value as? String, "Gtr R")
        XCTAssertTrue(app.buttons["color-green"].exists, "one colour for the pair")
        app.buttons["Cancel"].tap()

        app.buttons["EQ"].tap()
        XCTAssertTrue(element("/ch/09/eq/1/f").appears(within: 2))
        XCTAssertFalse(app.buttons["side-R"].exists, "the desk links the EQ")
        // The reset reaches both sides, so its alert names the pair, as the title does (mock A, 2026-10-27).
        let reset = app.buttons["Reset bands"]
        scrollUntilHittable(reset, from: app.buttons["/ch/09/eq/1/type"])
        reset.tap()
        let resetAlert = app.alerts["Reset all 4 bands of Gtr?"]
        XCTAssertTrue(resetAlert.appears(within: 2))
        saveScreenshot("pair-reset-alert")
        resetAlert.buttons["Cancel"].tap()

        app.buttons["Input"].tap()
        let phantom = app.buttons["toggle-/headamp/040/phantom"]
        XCTAssertTrue(phantom.appears(within: 2))
        phantom.tap()
        let phantomAlert = app.alerts["Turn on 48V for Gtr L?"]
        XCTAssertTrue(phantomAlert.appears(within: 2))
        XCTAssertTrue(phantomAlert.staticTexts["Also powers Gtr R (linked)."].exists, "48V names the partner")
        saveScreenshot("phantom-linked-alert")
        phantomAlert.buttons["Cancel"].tap()

        // An alert ignores opening while the last one still animates out (CLAUDE.md, System alerts).
        Thread.sleep(forTimeInterval: 0.4)
        app.buttons["toggle-/ch/09/preamp/invert"].tap()
        let flipAlert = app.alerts["Flip the polarity of Gtr L?"]
        XCTAssertTrue(flipAlert.appears(within: 2))
        let partnerLine = NSPredicate(format: "label CONTAINS %@", "Also flips Gtr R (linked).")
        XCTAssertTrue(flipAlert.staticTexts.containing(partnerLine).firstMatch.exists, "polarity names the partner")
        flipAlert.buttons["Cancel"].tap()
    }

    /// Linking only couples what the desk's Link Preferences tick: with the EQ unticked, the alert says it stays
    /// separate, and Cancel leaves the desk as it was.
    func testLinkAndUnlinkFromTheMixTab() {
        desk.change("/config/linkcfg/eq", 0)
        launch()
        app.buttons["Buses"].tap()
        app.buttons["Mon 3"].tap()
        let link = app.buttons["link-button"]
        XCTAssertTrue(link.appears(within: 3))
        XCTAssertEqual(link.label, "Stereo link with Mon 4 · Bus 4")

        link.tap()
        let alert = app.alerts["Link Mon 3 and Mon 4?"]
        XCTAssertTrue(alert.appears(within: 2))
        XCTAssertTrue(alert.staticTexts["They'll work as one stereo channel.\nEQ stays separate."].exists)
        saveScreenshot("link-alert")
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Bus 3"].exists, "Cancel leaves the desk as it was")
        XCTAssertEqual(desk.value("/config/buslink/3-4"), .int(0), "Cancel sends nothing")

        Thread.sleep(forTimeInterval: 0.4)
        link.tap()
        XCTAssertTrue(alert.appears(within: 2))
        alert.buttons["Link"].tap()
        XCTAssertTrue(app.navigationBars["Bus 3-4"].appears(within: 3))
        XCTAssertEqual(desk.value("/config/buslink/3-4"), .int(1), "linked on the desk")
        XCTAssertEqual(app.buttons["edit-strip"].value as? String, "Mon")
        XCTAssertEqual(link.label, "Unlink Mon 3 · Bus 3 and Mon 4 · Bus 4")

        link.tap()
        let unlink = app.alerts["Unlink Mon 3 and Mon 4?"]
        XCTAssertTrue(unlink.appears(within: 2))
        XCTAssertTrue(unlink.staticTexts["Each can be set on its own again."].exists)
        unlink.buttons["Unlink"].tap()
        XCTAssertTrue(app.navigationBars["Bus 3"].appears(within: 3))
        XCTAssertEqual(desk.value("/config/buslink/3-4"), .int(0), "unlinked on the desk")
    }

    /// The engineer unticks Dynamics and Gain/Delay Link on the desk: Gate and Comp show one side at a time, the
    /// Comp's sheet and key graph follow the side shown, and the 48V alert names no partner.
    func testAnUnlinkedSectionShowsOneSideAtATime() {
        desk.change("/config/linkcfg/dyn", 0)
        desk.change("/config/linkcfg/hadly", 0)
        desk.change("/ch/10/dyn/keysrc", 0)
        launchAndOpenGuitars()
        app.buttons["Comp"].tap()
        XCTAssertTrue(app.staticTexts["Dynamics aren't linked on the desk."].appears(within: 2))
        XCTAssertTrue(element("/ch/09/dyn/thr").exists)
        app.buttons["side-R"].tap()
        XCTAssertTrue(element("/ch/10/dyn/thr").appears(within: 2))
        XCTAssertFalse(element("/ch/09/dyn/thr").exists)
        saveScreenshot("pair-comp-unlinked")

        let line = app.buttons["comp-more"]
        XCTAssertTrue(line.appears(within: 2))
        line.tap()
        XCTAssertTrue(app.navigationBars["Comp · Gtr R"].appears(within: 2), "the sheet names the side it edits")
        XCTAssertTrue(eventually(within: 3) { self.desk.value(RTA.source) == .int(11) }, "the key graph hears ch 10")
        app.buttons["Done"].tap()

        app.buttons["EQ"].tap()
        XCTAssertTrue(element("/ch/09/eq/1/f").appears(within: 2))
        XCTAssertFalse(app.buttons["side-R"].exists, "the EQ is still linked")

        app.buttons["Input"].tap()
        let phantom = app.buttons["toggle-/headamp/040/phantom"]
        XCTAssertTrue(phantom.appears(within: 2))
        phantom.tap()
        let alert = app.alerts["Turn on 48V for Gtr L?"]
        XCTAssertTrue(alert.appears(within: 2))
        XCTAssertFalse(alert.staticTexts["Also powers Gtr R (linked)."].exists, "each side's preamp is its own")
        alert.buttons["Cancel"].tap()
    }

    /// The fader and the insert unlinked: the Mix tab shows one side, and its Insert sheet edits that side only.
    func testAOneSideInsertSheetNamesThatSide() {
        desk.change("/config/linkcfg/fdrmute", 0)
        desk.change("/config/linkcfg/dyn", 0)
        // An unlinked fader lists each side on the overview.
        launchAndOpen("Gtr L")
        let line = app.buttons["insert-more"]
        XCTAssertTrue(line.appears(within: 2))
        line.tap()
        XCTAssertTrue(app.navigationBars["Insert · Gtr L"].appears(within: 2))
    }

    /// With the EQ unlinked, the desk's RTA follows the side shown, not the side the tab opened on.
    func testTheRTAFollowsTheChosenSide() throws {
        desk.change("/config/linkcfg/eq", 0)
        launchAndOpenGuitars()
        app.buttons["EQ"].tap()
        let left = try XCTUnwrap(StripID(.input, 9).rtaSource)
        let right = try XCTUnwrap(StripID(.input, 10).rtaSource)
        XCTAssertTrue(eventually(within: 3) { self.desk.value(RTA.source) == .int(left) })
        app.buttons["side-R"].tap()
        XCTAssertTrue(eventually(within: 3) { self.desk.value(RTA.source) == .int(right) })
    }
}

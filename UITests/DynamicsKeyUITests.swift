import XCTest

/// The Comp's order, Auto time, and the folded line and sheets that hold the key, detector and comp position
/// (mocks 2026-10-20-fewer-options).
@MainActor
final class DynamicsKeyUITests: DeskUITestCase {
    /// Mock B (2026-10-20): the rows ridden mid-show, in reach without a scroll. U1: Auto last in the On · Mode row,
    /// so a tap that misses it opens Mode, never switches the comp off.
    func testRideRowsAreOnTheFirstScreen() {
        launchAndOpen("Kick", tab: "Comp")
        XCTAssertTrue(element("/ch/01/dyn/thr").appears(within: 2))
        for row in ["thr", "ratio", "mgain"] { XCTAssertTrue(element("/ch/01/dyn/" + row).isHittable, row) }
        let on = element("toggle-/ch/01/dyn/on")
        let auto = element("toggle-/ch/01/dyn/auto")
        XCTAssertEqual(auto.frame.midY, on.frame.midY, accuracy: 1, "Auto in the On · Mode row")
        XCTAssertGreaterThan(auto.frame.minX, element("/ch/01/dyn/mode").frame.maxX, "Auto last")
    }

    /// Auto time dims Attack and Release in place (the desk ignores them). What nobody rides is one line on the tab;
    /// its sheet has Source in the KEY heading, says its controls' full names, and when contact is lost says so itself.
    func testTheCompsSetOnceSettingsOpenFromOneLine() {
        launchAndOpen("Kick", tab: "Comp")
        let attack = element("/ch/01/dyn/attack")
        let release = element("/ch/01/dyn/release")
        XCTAssertTrue(eventually(within: 2) { attack.exists && attack.isEnabled })
        XCTAssertEqual(element("toggle-/ch/01/dyn/auto").label, "Auto time", "VoiceOver")
        tapToggle("/ch/01/dyn/auto")
        XCTAssertTrue(eventually(within: 2) { !attack.isEnabled && !release.isEnabled }, "Auto time dims A/R")
        XCTAssertTrue(element("/ch/01/dyn/hold").isEnabled, "Hold stays the engineer's")
        // The app's own edit holds the address for a moment: the desk's change after it must wait that out.
        Thread.sleep(forTimeInterval: 1)
        desk.change("/ch/01/dyn/auto", 0)
        XCTAssertTrue(eventually(within: 2) { attack.isEnabled && release.isEnabled }, "back when the desk turns it off")

        XCTAssertFalse(element("/ch/01/dyn/det").exists, "the detector lives in the sheet")
        openSheet("comp-more", title: "Comp · Kick")
        let source = element("/ch/01/dyn/keysrc")
        XCTAssertTrue(eventually(within: 2) { source.isEnabled })
        XCTAssertEqual(source.value as? String, "Self")
        XCTAssertEqual(source.label, "Listens to", "VoiceOver")
        XCTAssertLessThan(source.frame.maxY, element("toggle-/ch/01/dyn/filter/on").frame.minY, "above the filter")
        XCTAssertLessThan(source.frame.height, 48, "a text menu in the heading, not a row")
        let detector = app.buttons["/ch/01/dyn/det"]
        XCTAssertEqual(detector.label, "Detector", "VoiceOver")
        saveScreenshot("comp-sheet")
        tapToggle("/ch/01/dyn/filter/on")
        XCTAssertTrue(element("/ch/01/dyn/filter/f").exists)
        saveScreenshot("comp-key")

        // Last: the desk stays silent. A large sheet covers the tab's banner, so it shows its own.
        desk.goSilent()
        let banners = app.staticTexts.matching(NSPredicate(format: "label == %@", "Disconnected — retrying"))
        let sheetTop = app.navigationBars["Comp · Kick"].frame.maxY
        XCTAssertTrue(
            eventually(within: 8) { banners.allElementsBoundByIndex.contains { $0.frame.minY >= sheetTop - 1 } },
            "the sheet's own banner, under its title, not the tab's behind it")
        XCTAssertFalse(detector.isEnabled)
        XCTAssertTrue(app.buttons["Done"].isEnabled, "the sheet still closes")
    }

    /// The Key line says what the key listens to and whether its filter is on, in words (Slim, 2026-10-31).
    func testTheGateListensToAnotherChannel() {
        launchAndOpen("Kick", tab: "Gate")
        XCTAssertFalse(element("/ch/01/gate/keysrc").exists, "the key lives in its sheet")
        let line = element("gate-key")
        XCTAssertTrue(eventually(within: 2) { line.value as? String == "Self · Filter off" }, "step 1: the line")
        openSheet("gate-key", title: "Gate key · Kick")
        let source = app.buttons["/ch/01/gate/keysrc"]
        XCTAssertTrue(eventually(within: 2) { source.isEnabled })
        source.tap()
        let snare = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ch 2 · Snare")).firstMatch
        XCTAssertTrue(snare.appears(within: 2))
        snare.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/gate/keysrc") == .int(2) })
        tapToggle("/ch/01/gate/filter/on")
        saveScreenshot("gate-key")
        app.buttons["Done"].tap()
        XCTAssertTrue(
            eventually(within: 2) { line.value as? String == "Ch 2 · Snare · Filter on" }, "step 2: the line follows")
        saveScreenshot("gate-key-line")
    }

    /// The demo's sends are tapped before the fader: they hear the comp wherever it sits, so moving it asks nothing.
    /// A send tapped after the EQ starts hearing the comp once it moves before the EQ: then the app names it and asks.
    func testMovingTheCompAsksWhenAMixWouldChange() {
        launchAndOpen("Kick", tab: "Comp")
        openSheet("comp-more", title: "Comp · Kick")
        pick("Before EQ")
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/dyn/pos") == .int(0) }, "moved without asking")
        XCTAssertEqual(app.alerts.count, 0)
        pick("After EQ")
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/dyn/pos") == .int(1) }, "moved back")

        desk.change("/ch/01/mix/01/on", 1)
        desk.change("/ch/01/mix/01/type", 2)
        Thread.sleep(forTimeInterval: 1)
        pick("Before EQ")
        XCTAssertTrue(app.alerts["Move the comp before the EQ?"].appears(within: 2), "a send after the EQ: it asks")
        saveScreenshot("comp-position-alert")
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(desk.value("/ch/01/dyn/pos"), .int(1))
        Thread.sleep(forTimeInterval: 0.4)
        pick("Before EQ")
        XCTAssertTrue(app.alerts.buttons["Move"].appears(within: 2))
        app.alerts.buttons["Move"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/dyn/pos") == .int(0) })
    }

    private func openSheet(_ line: String, title: String) {
        let button = app.buttons[line]
        XCTAssertTrue(button.appears(within: 2), line)
        button.tap()
        XCTAssertTrue(app.navigationBars[title].appears(within: 2), title)
    }

    private func tapToggle(_ address: String) {
        let toggle = app.buttons["toggle-" + address]
        XCTAssertTrue(toggle.appears(within: 2), address)
        toggle.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value(address) == .int(1) }, address)
    }

    private func pick(_ position: String) {
        let menu = app.buttons["/ch/01/dyn/pos"]
        XCTAssertTrue(eventually(within: 3) { menu.exists && menu.isEnabled }, "the taps were never read")
        menu.tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", position)).firstMatch
        XCTAssertTrue(option.appears(within: 2), position)
        option.tap()
    }
}

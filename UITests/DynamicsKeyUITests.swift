import XCTest

/// Auto time, the key and the comp position, below everything an engineer rides (mocks 2026-10-14-dyn-key).
@MainActor
final class DynamicsKeyUITests: DeskUITestCase {
    /// Mock B (2026-10-20): the rows ridden mid-show, in reach without a scroll.
    func testRideRowsAreOnTheFirstScreen() {
        launchAndOpen("Kick", tab: "Comp")
        XCTAssertTrue(element("/ch/01/dyn/thr").appears(within: 2))
        for row in ["thr", "ratio", "mgain"] { XCTAssertTrue(element("/ch/01/dyn/" + row).isHittable, row) }
    }

    /// U1 (2026-10-20): Auto last in the On · Mode row, so a tap that misses it opens Mode, never switches the comp off.
    func testAutoSitsBesideOnAndMode() {
        launchAndOpen("Kick", tab: "Comp")
        let on = element("toggle-/ch/01/dyn/on")
        let auto = element("toggle-/ch/01/dyn/auto")
        XCTAssertTrue(auto.appears(within: 2))
        XCTAssertEqual(auto.frame.midY, on.frame.midY, accuracy: 1)
        XCTAssertGreaterThan(auto.frame.minX, element("/ch/01/dyn/mode").frame.maxX)
    }

    func testAutoTimeAndTheCompsKeyFilterSwitch() {
        launchAndOpen("Kick", tab: "Comp")
        tapToggle("/ch/01/dyn/auto")
        openSheet("comp-more", title: "Comp · Kick")
        XCTAssertEqual(element("/ch/01/dyn/keysrc").value as? String, "Self")
        tapToggle("/ch/01/dyn/filter/on")
        XCTAssertTrue(element("/ch/01/dyn/filter/f").exists)
        saveScreenshot("comp-key")
    }

    /// Mock B + S2 (2026-10-20): what nobody rides is one line on the tab; the sheet has Source in the KEY heading.
    func testTheCompsSetOnceSettingsOpenFromOneLine() {
        launchAndOpen("Kick", tab: "Comp")
        XCTAssertFalse(element("/ch/01/dyn/det").exists)
        openSheet("comp-more", title: "Comp · Kick")
        let source = element("/ch/01/dyn/keysrc")
        XCTAssertTrue(eventually(within: 2) { source.isEnabled })
        XCTAssertEqual(source.value as? String, "Self")
        XCTAssertLessThan(source.frame.maxY, element("toggle-/ch/01/dyn/filter/on").frame.minY, "above the filter")
        XCTAssertLessThan(source.frame.height, 48, "a text menu in the heading, not a row")
        XCTAssertTrue(element("/ch/01/dyn/det").exists)
        saveScreenshot("comp-sheet")
    }

    /// A large sheet covers the tab's banner: it says itself that contact is gone, and its controls stop.
    func testASheetSaysWhenContactIsLost() {
        launchAndOpen("Kick", tab: "Comp")
        openSheet("comp-more", title: "Comp · Kick")
        let detector = app.buttons["/ch/01/dyn/det"]
        XCTAssertTrue(eventually(within: 2) { detector.isEnabled })
        desk.goSilent()
        XCTAssertTrue(app.staticTexts["Disconnected — retrying"].appears(within: 8))
        XCTAssertFalse(detector.isEnabled)
    }

    /// The desk ignores Attack and Release under Auto time: dimmed in place, back when Auto time goes off.
    func testAutoTimeDimsAttackAndRelease() {
        desk.change("/ch/01/dyn/auto", 1)
        launchAndOpen("Kick", tab: "Comp")
        let attack = element("/ch/01/dyn/attack")
        let release = element("/ch/01/dyn/release")
        XCTAssertTrue(eventually(within: 2) { attack.exists && !attack.isEnabled && !release.isEnabled })
        XCTAssertTrue(element("/ch/01/dyn/hold").isEnabled, "Hold stays the engineer's")
        scrollDown(from: "/ch/01/dyn/mode")
        saveScreenshot("comp-auto-time")
        desk.change("/ch/01/dyn/auto", 0)
        XCTAssertTrue(eventually(within: 2) { attack.isEnabled && release.isEnabled })
    }

    func testTheGateListensToAnotherChannel() {
        launchAndOpen("Kick", tab: "Gate")
        XCTAssertFalse(element("/ch/01/gate/keysrc").exists, "the key lives in its sheet")
        openSheet("gate-key", title: "Gate key · Kick")
        let source = app.buttons["/ch/01/gate/keysrc"]
        XCTAssertTrue(eventually(within: 2) { source.isEnabled })
        source.tap()
        let snare = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ch 2 · Snare")).firstMatch
        XCTAssertTrue(snare.appears(within: 2))
        snare.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/gate/keysrc") == .int(2) })
        saveScreenshot("gate-key")
        app.buttons["Done"].tap()
        let line = element("gate-key")
        XCTAssertTrue(eventually(within: 2) { (line.value as? String)?.hasPrefix("Ch 2 · Snare") == true })
    }

    /// A send tapped after the EQ starts hearing the comp once it moves before the EQ: the app names it and asks.
    func testMovingTheCompAsksWhenAMixWouldChange() {
        desk.change("/ch/01/mix/01/on", 1)
        desk.change("/ch/01/mix/01/type", 2)
        launchAndOpen("Kick", tab: "Comp")
        openSheet("comp-more", title: "Comp · Kick")
        pickBeforeEQ()
        XCTAssertTrue(app.alerts["Move the comp before the EQ?"].appears(within: 2))
        saveScreenshot("comp-position-alert")
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(desk.value("/ch/01/dyn/pos"), .int(1))
        pickBeforeEQ()
        XCTAssertTrue(app.alerts.buttons["Move"].appears(within: 2))
        app.alerts.buttons["Move"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/dyn/pos") == .int(0) })
    }

    /// The demo's sends are tapped before the fader: they hear the comp wherever it sits, so nothing asks.
    func testMovingTheCompWithNoMixChangingDoesntAsk() {
        launchAndOpen("Kick", tab: "Comp")
        openSheet("comp-more", title: "Comp · Kick")
        pickBeforeEQ()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/dyn/pos") == .int(0) })
        XCTAssertEqual(app.alerts.count, 0)
    }

    /// From a dropdown, never a drag row: a drag there would change its value (CLAUDE.md, 375 pt screen edge).
    private func scrollDown(from address: String) {
        let menu = app.buttons[address]
        XCTAssertTrue(menu.appears(within: 2), address)
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
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

    private func pickBeforeEQ() {
        let menu = app.buttons["/ch/01/dyn/pos"]
        XCTAssertTrue(eventually(within: 3) { menu.exists && menu.isEnabled }, "the taps were never read")
        menu.tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Before EQ")).firstMatch
        XCTAssertTrue(option.appears(within: 2))
        option.tap()
    }
}

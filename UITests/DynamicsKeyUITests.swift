import XCTest

/// Auto time, the key and the comp position, below everything an engineer rides (mocks 2026-10-14-dyn-key).
@MainActor
final class DynamicsKeyUITests: DeskUITestCase {
    func testAutoTimeAndTheCompsKeyFilterSwitch() {
        launch()
        open("Kick")
        app.buttons["Comp"].tap()
        scrollDown(from: "/ch/01/dyn/mode")
        tapToggle("/ch/01/dyn/auto")
        XCTAssertEqual(element("/ch/01/dyn/keysrc").value as? String, "Self")
        tapToggle("/ch/01/dyn/filter/on")
        XCTAssertTrue(element("/ch/01/dyn/filter/f").exists)
        saveScreenshot("comp-key")
    }

    /// The desk ignores Attack and Release under Auto time: dimmed in place, back when Auto time goes off.
    func testAutoTimeDimsAttackAndRelease() {
        desk.change("/ch/01/dyn/auto", 1)
        launch()
        open("Kick")
        app.buttons["Comp"].tap()
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
        launch()
        open("Kick")
        app.buttons["Gate"].tap()
        scrollDown(from: "/ch/01/gate/mode")
        let source = app.buttons["/ch/01/gate/keysrc"]
        XCTAssertTrue(source.appears(within: 2))
        source.tap()
        let snare = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ch 2 · Snare")).firstMatch
        XCTAssertTrue(snare.appears(within: 2))
        snare.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/gate/keysrc") == .int(2) })
        saveScreenshot("gate-key")
    }

    /// A send tapped after the EQ starts hearing the comp once it moves before the EQ: the app names it and asks.
    func testMovingTheCompAsksWhenAMixWouldChange() {
        desk.change("/ch/01/mix/01/on", 1)
        desk.change("/ch/01/mix/01/type", 2)
        launch()
        open("Kick")
        app.buttons["Comp"].tap()
        scrollDown(from: "/ch/01/dyn/mode")
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
        launch()
        open("Kick")
        app.buttons["Comp"].tap()
        scrollDown(from: "/ch/01/dyn/mode")
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

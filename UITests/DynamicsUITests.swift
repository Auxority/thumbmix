import XCTest

@MainActor
final class DynamicsUITests: DeskUITestCase {
    /// A drag on Threshold reaches the desk; Mode is a list (a drag past half the row to flip it was easy to miss).
    func testGateTabEditsThreshold() {
        launchAndOpen("Kick", tab: "Gate")
        let threshold = app.descendants(matching: .any)["/ch/01/gate/thr"]
        XCTAssertTrue(threshold.appears(within: 2))
        let before = threshold.value as? String
        let deskBefore = desk.value("/ch/01/gate/thr")
        threshold.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.05,
                thenDragTo: threshold.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        XCTAssertNotEqual(threshold.value as? String, before)
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/gate/thr") != deskBefore }, "on the desk")
        XCTAssertTrue(app.descendants(matching: .any)["/ch/01/gate/release"].exists)
        saveScreenshot("task-14-gate")
        pick("Ducker", in: "/ch/01/gate/mode", from: "GATE", to: "DUCK")
        resetGateAsksFirst()
    }

    /// The shape only: mode and threshold go back (provisional values, `Catalog.gateDefaults`), On stays.
    private func resetGateAsksFirst() {
        let mode = app.buttons["/ch/01/gate/mode"]
        let reset = app.buttons["Reset gate"]
        scrollUntilHittable(reset, from: mode)
        saveScreenshot("gate-reset")
        let on = desk.value("/ch/01/gate/on")
        reset.tap()
        let alert = app.alerts["Reset the gate of Kick?"]
        XCTAssertTrue(alert.appears(within: 2))
        saveScreenshot("gate-reset-alert")
        alert.buttons["Cancel"].tap()
        XCTAssertEqual(mode.value as? String, "DUCK", "Cancel leaves the gate")
        reset.tap()
        alert.buttons["Reset"].tap()
        XCTAssertTrue(eventually(within: 2) { mode.value as? String == "GATE" })
        XCTAssertTrue(
            eventually(within: 2) {
                self.desk.value("/ch/01/gate/mode") == .int(3) && self.desk.value("/ch/01/gate/thr") == .float(0)
            }, "GATE, always open, on the desk")
        XCTAssertEqual(desk.value("/ch/01/gate/on"), on, "On stays as switched")
    }

    /// Graph first, like the EQ tab, one size on EQ, Gate and Comp (layout A, 2026-10-17). Its space is kept until
    /// the curve's values arrive, so On never jumps. Comp mix is the last row an engineer rides (mock A, 2026-10-16).
    func testGraphsComeFirstAndNeverMoveTheRows() {
        desk.forget("/ch/01/gate/thr")
        desk.forget("/ch/01/dyn/thr")
        launchAndOpen("Kick", tab: "EQ")
        let eq = element("eq-graph")
        XCTAssertTrue(eq.appears(within: 2))
        let size = eq.frame.size

        app.buttons["Gate"].tap()
        graphSitsAboveItsSwitches(prefix: "/ch/01/gate/", graph: "gate-graph", size: size)

        app.buttons["Comp"].tap()
        graphSitsAboveItsSwitches(prefix: "/ch/01/dyn/", graph: "comp-graph", size: size)
        let mix = element("/ch/01/dyn/mix")
        XCTAssertTrue(mix.appears(within: 2))
        XCTAssertEqual(mix.label, "Comp mix")
        XCTAssertEqual(mix.value as? String, "100%")
        let makeup = element("/ch/01/dyn/mgain")
        XCTAssertEqual(mix.frame.minY, makeup.frame.maxY + 8, accuracy: 1, "Comp mix right under Makeup gain")
    }

    private func graphSitsAboveItsSwitches(prefix: String, graph identifier: String, size: CGSize) {
        let on = element("toggle-" + prefix + "on")
        XCTAssertTrue(eventually(within: 2) { on.isEnabled }, "the tab was read")
        let before = on.frame.minY
        desk.change(prefix + "thr", float: 0.5)
        let graph = element(identifier)
        XCTAssertTrue(graph.appears(within: 2))
        XCTAssertLessThan(graph.frame.maxY, on.frame.minY, identifier + " above the switches")
        XCTAssertEqual(on.frame.minY, before, "the switches stayed put")
        XCTAssertEqual(graph.frame.size, size, identifier + " as large as the EQ's")
        XCTAssertTrue(element(prefix + "thr").isHittable, "Threshold on the first screen")
        saveScreenshot(identifier + "-first")
    }

    /// Every choice is a list: the open list says it in words, the closed row the desk's name for it.
    func testCompChoicesAreDropdowns() {
        launchAndOpen("Snare", tab: "Comp")
        pick("Expander", in: "/ch/02/dyn/mode", from: "COMP", to: "EXP")
        let line = app.buttons["comp-more"]
        XCTAssertTrue(line.appears(within: 2))
        line.tap()
        XCTAssertTrue(app.navigationBars["Comp · Snare"].appears(within: 2))
        pick("Average level", in: "/ch/02/dyn/det", from: "PEAK", to: "RMS")
        pick("Linear", in: "/ch/02/dyn/env", from: "LOG", to: "LIN")
        saveScreenshot("comp-dropdowns")
        app.buttons["Done"].tap()
        resetCompAsksFirst()
    }

    /// The shape only, the sheet's detector and envelope included (provisional values, `Catalog.dynamicsDefaults`).
    private func resetCompAsksFirst() {
        let mode = app.buttons["/ch/02/dyn/mode"]
        let reset = app.buttons["Reset comp"]
        scrollUntilHittable(reset, from: mode)
        saveScreenshot("comp-reset")
        reset.tap()
        let alert = app.alerts["Reset the comp of Snare?"]
        XCTAssertTrue(alert.appears(within: 2))
        saveScreenshot("comp-reset-alert")
        alert.buttons["Cancel"].tap()
        XCTAssertEqual(mode.value as? String, "EXP", "Cancel leaves the comp")
        reset.tap()
        alert.buttons["Reset"].tap()
        XCTAssertTrue(eventually(within: 2) { mode.value as? String == "COMP" })
        XCTAssertTrue(
            eventually(within: 2) {
                self.desk.value("/ch/02/dyn/det") == .int(0) && self.desk.value("/ch/02/dyn/env") == .int(1)
            }, "PEAK and LOG on the desk")
    }

    private func pick(_ item: String, in address: String, from current: String, to deskName: String) {
        let menu = app.buttons[address]
        XCTAssertTrue(menu.appears(within: 2), address)
        XCTAssertEqual(menu.value as? String, current)
        menu.tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", item)).firstMatch
        XCTAssertTrue(option.appears(within: 2), item)
        option.tap()
        XCTAssertTrue(eventually(within: 2) { menu.value as? String == deskName }, address)
    }

    /// Off, the curve forks: the straight line is heard, the bend waits dashed (F1, 2026-10-17).
    func testSwitchingCompOffSaysSoOnItsGraph() {
        launchAndOpen("Kick", tab: "Comp")
        let graph = element("comp-graph")
        let on = element("toggle-/ch/01/dyn/on")
        XCTAssertTrue(eventually(within: 2) { on.isEnabled }, "the tab was read")
        let wasOff = graph.value as? String == "Off"
        on.tap()
        XCTAssertTrue(eventually(within: 2) { (graph.value as? String == "Off") != wasOff })
        if !wasOff { assertNoReduction() }
        saveScreenshot(wasOff ? "comp-on-fork" : "comp-off-fork")
        on.tap()
        XCTAssertTrue(eventually(within: 2) { (graph.value as? String == "Off") == wasOff })
        if wasOff { assertNoReduction() }
        saveScreenshot(wasOff ? "comp-off-fork" : "comp-on-fork")
    }

    /// Off reduces nothing, whatever the meter says (the demo's meters animate regardless).
    private func assertNoReduction() {
        let none = app.staticTexts["GR 0.0 dB"]
        XCTAssertTrue(none.appears(within: 2))
        XCTAssertFalse(eventually(within: 1) { !none.exists }, "stays at 0 while the meter moves")
    }
}

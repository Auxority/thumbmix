import XCTest

@MainActor
final class DynamicsUITests: DeskUITestCase {
    func testGateTabEditsThreshold() {
        launchAndOpen("Kick", tab: "Gate")
        let threshold = app.descendants(matching: .any)["/ch/01/gate/thr"]
        XCTAssertTrue(threshold.appears(within: 2))
        let before = threshold.value as? String
        threshold.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.05,
                thenDragTo: threshold.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        XCTAssertNotEqual(threshold.value as? String, before)
        XCTAssertTrue(app.descendants(matching: .any)["/ch/01/gate/release"].exists)
        saveScreenshot("task-14-gate")
    }

    /// Graph first, like the EQ tab. Its space is kept until the curve's values arrive, so On never jumps.
    func testGateGraphSitsAboveItsSwitchesWhichNeverMove() {
        graphSitsAboveItsSwitches(tab: "Gate", prefix: "/ch/01/gate/", graph: "gate-graph")
    }

    func testCompGraphSitsAboveItsSwitchesWhichNeverMove() {
        graphSitsAboveItsSwitches(tab: "Comp", prefix: "/ch/01/dyn/", graph: "comp-graph")
    }

    private func graphSitsAboveItsSwitches(tab: String, prefix: String, graph identifier: String) {
        desk.forget(prefix + "thr")
        launchAndOpen("Kick", tab: tab)
        let on = element("toggle-" + prefix + "on")
        XCTAssertTrue(eventually(within: 2) { on.isEnabled }, "the tab was read")
        let before = on.frame.minY
        desk.change(prefix + "thr", float: 0.5)
        let graph = element(identifier)
        XCTAssertTrue(graph.appears(within: 2))
        XCTAssertLessThan(graph.frame.maxY, on.frame.minY)
        XCTAssertEqual(on.frame.minY, before, "the switches stayed put")
        XCTAssertTrue(element(prefix + "thr").isHittable, "Threshold on the first screen")
        saveScreenshot(identifier + "-first")
    }

    func testCompTabShowsRatioAndMakeupGain() {
        launchAndOpen("Kick", tab: "Comp")
        XCTAssertEqual(app.descendants(matching: .any)["/ch/01/dyn/ratio"].value as? String, "2.0:1")
        XCTAssertEqual(app.descendants(matching: .any)["/ch/01/dyn/mgain"].label, "Makeup gain")
    }

    /// Mock A (2026-10-16): the last row an engineer rides, so nothing above it moves.
    func testCompMixSitsUnderMakeupGain() {
        launchAndOpen("Kick", tab: "Comp")
        let mix = element("/ch/01/dyn/mix")
        XCTAssertTrue(mix.appears(within: 2))
        XCTAssertEqual(mix.label, "Comp mix")
        XCTAssertEqual(mix.value as? String, "100%")
        let makeup = element("/ch/01/dyn/mgain")
        XCTAssertEqual(mix.frame.minY, makeup.frame.maxY + 8, accuracy: 1, "right under Makeup gain")
    }

    /// Dragging past half the row to flip a two-way choice was easy to miss; a list shows both.
    func testCompModeIsADropdown() {
        launchAndOpen("Kick", tab: "Comp")
        pick("Expander", in: "/ch/01/dyn/mode", from: "COMP", to: "EXP")
    }

    func testGateModeIsADropdown() {
        launchAndOpen("Kick", tab: "Gate")
        pick("Ducker", in: "/ch/01/gate/mode", from: "GATE", to: "DUCK")
    }

    func testDetectorAndEnvelopeAreDropdowns() {
        launchAndOpen("Snare", tab: "Comp")
        pick("Average level", in: "/ch/02/dyn/det", from: "PEAK", to: "RMS")
        pick("Linear", in: "/ch/02/dyn/env", from: "LOG", to: "LIN")
        saveScreenshot("comp-dropdowns")
    }

    /// Like the EQ rows: a double-tap resets at once, no question.
    func testDoubleTapResetsMakeupGainAndRatioAtOnce() {
        launchAndOpen("Tom 1", tab: "Comp")
        let makeup = app.descendants(matching: .any)["/ch/04/dyn/mgain"]
        XCTAssertTrue(makeup.appears(within: 2))
        XCTAssertEqual(makeup.value as? String, "12.0 dB")
        makeup.doubleTap()
        XCTAssertTrue(eventually(within: 2) { makeup.value as? String == "0.0 dB" })

        let ratio = app.descendants(matching: .any)["/ch/04/dyn/ratio"]
        XCTAssertEqual(ratio.value as? String, "2.0:1")
        ratio.doubleTap()
        XCTAssertTrue(eventually(within: 2) { ratio.value as? String == "3.0:1" })
        XCTAssertEqual(app.alerts.count, 0)
    }

    /// The open list says the choice in words; the closed row shows the desk's name for it.
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

    /// Switching EQ, Gate and Comp never resizes the plot (layout A, 2026-10-17).
    func testEQGateAndCompGraphsShareOneSize() {
        launchAndOpen("Kick", tab: "EQ")
        let eq = element("eq-graph")
        XCTAssertTrue(eq.appears(within: 2))
        let size = eq.frame.size
        app.buttons["Gate"].tap()
        let gate = element("gate-graph")
        XCTAssertTrue(gate.appears(within: 2))
        XCTAssertEqual(gate.frame.size, size)
        app.buttons["Comp"].tap()
        let comp = element("comp-graph")
        XCTAssertTrue(comp.appears(within: 2))
        XCTAssertEqual(comp.frame.size, size)
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

    func testGateAndCompDrawTheirCurves() {
        launchAndOpen("Kick", tab: "Gate")
        XCTAssertTrue(app.descendants(matching: .any)["gate-graph"].appears(within: 2))
        saveScreenshot("gate-graph")
        app.buttons["Comp"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["comp-graph"].appears(within: 2))
        XCTAssertEqual(app.descendants(matching: .any)["/ch/01/dyn/mode"].value as? String, "COMP")
        saveScreenshot("comp-graph")
    }

    func testBusHasCompButNoGate() {
        launchAndOpen("Mon 1", group: "Buses")
        XCTAssertFalse(app.buttons["Gate"].exists)
        app.buttons["Comp"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["/bus/01/dyn/thr"].appears(within: 2))
    }
}

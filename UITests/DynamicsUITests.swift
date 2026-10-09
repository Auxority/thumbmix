import XCTest

@MainActor
final class DynamicsUITests: DeskUITestCase {
    func testGateTabEditsThreshold() {
        launch()
        open("Kick")
        app.buttons["Gate"].tap()
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

    func testCompTabShowsRatioAndMakeupGain() {
        launch()
        open("Kick")
        app.buttons["Comp"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["/ch/01/dyn/ratio"].value as? String, "2.0:1")
        XCTAssertEqual(app.descendants(matching: .any)["/ch/01/dyn/mgain"].label, "Makeup gain")
    }

    /// Dragging past half the row to flip a two-way choice was easy to miss; a list shows both.
    func testCompModeIsADropdown() {
        launch()
        open("Kick")
        app.buttons["Comp"].tap()
        pick("Expander", in: "/ch/01/dyn/mode", from: "COMP", to: "EXP")
    }

    func testGateModeIsADropdown() {
        launch()
        open("Kick")
        app.buttons["Gate"].tap()
        pick("Ducker", in: "/ch/01/gate/mode", from: "GATE", to: "DUCK")
    }

    func testDetectorAndEnvelopeAreDropdowns() {
        launch()
        open("Snare")
        app.buttons["Comp"].tap()
        pick("Average level", in: "/ch/02/dyn/det", from: "PEAK", to: "RMS")
        pick("Linear", in: "/ch/02/dyn/env", from: "LOG", to: "LIN")
        saveScreenshot("comp-dropdowns")
    }

    /// Makeup gain back to 0 dB can only make the channel quieter, so it goes at once; a ratio reset can
    /// make it louder, so it asks.
    func testDoubleTapResetsMakeupGainAtOnceAndRatioAfterAsking() {
        launch()
        open("Tom 1")
        app.buttons["Comp"].tap()
        let makeup = app.descendants(matching: .any)["/ch/04/dyn/mgain"]
        XCTAssertTrue(makeup.appears(within: 2))
        XCTAssertEqual(makeup.value as? String, "12.0 dB")
        makeup.doubleTap()
        XCTAssertTrue(eventually(within: 2) { makeup.value as? String == "0.0 dB" })
        XCTAssertEqual(app.alerts.count, 0)

        let ratio = app.descendants(matching: .any)["/ch/04/dyn/ratio"]
        ratio.doubleTap()
        let alert = app.alerts["Reset the ratio to 3:1?"]
        XCTAssertTrue(alert.appears(within: 2))
        alert.buttons["Reset"].tap()
        XCTAssertTrue(eventually(within: 2) { ratio.value as? String == "3.0:1" })
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

    func testGateAndCompDrawTheirCurves() {
        launch()
        open("Kick")
        app.buttons["Gate"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["gate-graph"].appears(within: 2))
        saveScreenshot("gate-graph")
        app.buttons["Comp"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["comp-graph"].appears(within: 2))
        XCTAssertEqual(app.descendants(matching: .any)["/ch/01/dyn/mode"].value as? String, "COMP")
        saveScreenshot("comp-graph")
    }

    func testBusHasCompButNoGate() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        XCTAssertFalse(app.buttons["Gate"].exists)
        app.buttons["Comp"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["/bus/01/dyn/thr"].appears(within: 2))
    }
}

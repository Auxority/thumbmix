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

    func testCompTabShowsRatioAndMakeup() {
        launch()
        open("Kick")
        app.buttons["Comp"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["/ch/01/dyn/ratio"].value as? String, "2.0:1")
        XCTAssertTrue(app.descendants(matching: .any)["/ch/01/dyn/mgain"].exists)
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

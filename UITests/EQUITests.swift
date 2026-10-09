import XCTest

@MainActor
final class EQUITests: DeskUITestCase {
    /// Where band 1 of an input sits on the graph at its default: 91.4 Hz on the log axis, 0 dB.
    private static let kickBand1 = CGVector(dx: log(91.4 / 20) / log(1000), dy: 0.5)

    func testDraggingOnTheGraphMovesTheGrabbedBand() {
        launch()
        open("Kick")
        app.buttons["EQ"].tap()
        let frequency = app.descendants(matching: .any)["/ch/01/eq/1/f"]
        let gain = app.descendants(matching: .any)["/ch/01/eq/1/g"]
        XCTAssertTrue(frequency.appears(within: 2))
        XCTAssertEqual(frequency.value as? String, "91.4 Hz")
        let graph = app.descendants(matching: .any)["eq-graph"]

        graph.coordinate(withNormalizedOffset: Self.kickBand1)
            .press(
                forDuration: 0.1,
                thenDragTo: graph.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))

        XCTAssertNotEqual(frequency.value as? String, "91.4 Hz")
        XCTAssertNotEqual(gain.value as? String, "0.0 dB")
        saveScreenshot("task-15-eq")
    }

    /// A touch near a band point grabs it, but only movement moves it: landing slightly off the point
    /// must not jump the desk to where the finger happens to be.
    func testTouchingNearABandChangesNothing() {
        launch()
        open("Tom 2")
        app.buttons["EQ"].tap()
        let frequency = app.descendants(matching: .any)["/ch/05/eq/1/f"]
        let gain = app.descendants(matching: .any)["/ch/05/eq/1/g"]
        XCTAssertTrue(frequency.appears(within: 2))
        let graph = app.descendants(matching: .any)["eq-graph"]
        let nearBand1 = graph.coordinate(withNormalizedOffset: Self.kickBand1).withOffset(CGVector(dx: 20, dy: -25))
        nearBand1.press(forDuration: 0.3)
        XCTAssertEqual(frequency.value as? String, "91.4 Hz")
        XCTAssertEqual(gain.value as? String, "0.0 dB")
    }

    func testEQTabScrollsAsAWhole() {
        launch()
        open("Tom 1")
        app.buttons["EQ"].tap()
        let graph = app.descendants(matching: .any)["eq-graph"]
        XCTAssertTrue(graph.appears(within: 2))
        let top = graph.frame.minY
        // Drag from the Type row: on a 375 pt phone the rows below it start at the screen's bottom edge.
        let type = app.buttons["/ch/04/eq/1/type"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        type.press(forDuration: 0.05, thenDragTo: type.withOffset(CGVector(dx: 0, dy: -250)))
        XCTAssertLessThan(graph.frame.minY, top)
        saveScreenshot("eq-scrolled")
    }

    func testBandTypeIsADropdown() {
        launch()
        open("Tom 1")
        app.buttons["EQ"].tap()
        let type = app.buttons["/ch/04/eq/1/type"]
        XCTAssertTrue(type.appears(within: 2))
        XCTAssertEqual(type.value as? String, "PEQ")
        type.tap()
        app.buttons["LShv"].tap()
        XCTAssertEqual(type.value as? String, "LShv")
    }

    func testResetBandsAsksFirst() {
        launch()
        open("Snare")
        app.buttons["EQ"].tap()
        let frequency = app.descendants(matching: .any)["/ch/02/eq/1/f"]
        // 5 s: in one full-suite run the EQ rows took over 2 s to appear on a busy simulator.
        XCTAssertTrue(frequency.appears(within: 5))
        frequency.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: frequency.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
        let moved = frequency.value as? String
        XCTAssertNotEqual(moved, "91.4 Hz")
        // Drag from the Type row: on a 375 pt phone the rows below it can start past the screen's bottom edge.
        let type = app.buttons["/ch/02/eq/1/type"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        type.press(forDuration: 0.05, thenDragTo: type.withOffset(CGVector(dx: 0, dy: -300)))
        // The system alert, like every other "are you sure" in the app.
        app.buttons["Reset bands"].tap()
        let alert = app.alerts["Reset all 4 bands of Snare?"]
        XCTAssertTrue(alert.appears(within: 2))
        alert.buttons["Cancel"].tap()
        XCTAssertEqual(frequency.value as? String, moved)
        app.buttons["Reset bands"].tap()
        alert.buttons["Reset"].tap()
        XCTAssertEqual(frequency.value as? String, "91.4 Hz")
    }

    func testDoubleTappingABandResetsIt() {
        launch()
        open("Hi-hat")
        app.buttons["EQ"].tap()
        let gain = app.descendants(matching: .any)["/ch/03/eq/1/g"]
        XCTAssertTrue(gain.appears(within: 2))
        let graph = app.descendants(matching: .any)["eq-graph"]
        let raised = CGVector(dx: Self.kickBand1.dx, dy: 0.25)
        graph.coordinate(withNormalizedOffset: Self.kickBand1)
            .press(forDuration: 0.1, thenDragTo: graph.coordinate(withNormalizedOffset: raised))
        XCTAssertNotEqual(gain.value as? String, "0.0 dB")
        graph.coordinate(withNormalizedOffset: raised).doubleTap()
        XCTAssertTrue(eventually(within: 2) { gain.value as? String == "0.0 dB" })
    }

    func testLowCutIsTheFirstChoiceInTheBandPicker() {
        launch()
        open("OH L")
        app.buttons["EQ"].tap()
        app.buttons["LC"].tap()
        let on = app.descendants(matching: .any)["toggle-/ch/06/preamp/hpon"]
        XCTAssertTrue(on.appears(within: 2))
        XCTAssertEqual(on.value as? String, "Off")
        XCTAssertEqual(app.descendants(matching: .any)["/ch/06/preamp/hpf"].value as? String, "89.4 Hz")
        let slope = app.buttons["/ch/06/preamp/hpslope"]
        XCTAssertEqual(slope.value as? String, "24 dB/oct")
        slope.tap()
        app.buttons["12 dB/oct"].tap()
        XCTAssertEqual(slope.value as? String, "12 dB/oct")
        on.tap()
        XCTAssertEqual(on.value as? String, "On")
        saveScreenshot("low-cut")
    }

    /// The EQ tab borrows the desk's RTA for this channel; the status line shows once spectrum data arrives.
    func testEQTabShowsTheLiveSpectrum() {
        launch()
        open("Kick")
        app.buttons["EQ"].tap()
        let status = app.staticTexts["rta-status"]
        XCTAssertTrue(eventually(within: 5) { status.exists && status.label == "RTA follows Kick (after EQ)" })
        saveScreenshot("eq-spectrum")
    }

    /// Coming back from another app rebuilds the link; the RTA must be borrowed again once it is live.
    func testTheSpectrumComesBackAfterTheBackground() {
        launch()
        open("Kick")
        app.buttons["EQ"].tap()
        let status = app.staticTexts["rta-status"]
        XCTAssertTrue(eventually(within: 5) { status.exists && status.label == "RTA follows Kick (after EQ)" })
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(eventually(within: 5) { [.runningBackground, .runningBackgroundSuspended].contains(self.app.state) })
        app.activate()
        XCTAssertTrue(eventually(within: 10) { status.exists && status.label == "RTA follows Kick (after EQ)" })
    }

    /// The RTA status line appeared only once spectrum data came in, pushing everything under it down a line:
    /// Reset bands showed for a moment, then jumped.
    func testNothingMovesWhenTheSpectrumArrives() {
        launch()
        open("Kick")
        app.buttons["EQ"].tap()
        let reset = app.buttons["Reset bands"]
        XCTAssertTrue(reset.appears(within: 2))
        let before = reset.frame.minY
        let status = app.staticTexts["rta-status"]
        XCTAssertTrue(eventually(within: 5) { status.exists && status.label == "RTA follows Kick (after EQ)" })
        XCTAssertEqual(reset.frame.minY, before, accuracy: 0.5)
    }

    func testBusEQHasSixBands() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        app.buttons["EQ"].tap()
        XCTAssertTrue(app.buttons["6"].appears(within: 2))
        XCTAssertFalse(app.buttons["LC"].exists, "buses have no low cut")
    }
}

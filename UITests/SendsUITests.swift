import XCTest

/// Sends: an input's to the buses, a bus's or main's to the matrices (mock B), and the Fed by tabs.
@MainActor
final class SendsUITests: DeskUITestCase {
    /// A bus's Sends sit before Fed by, which keeps the far right: mix buses use it more.
    func testABusSendsToTheMatricesBeforeItsFedByTab() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        let sends = app.buttons["Sends"]
        XCTAssertTrue(sends.exists)
        XCTAssertLessThan(sends.frame.minX, app.buttons["Fed by"].frame.minX, "Sends before Fed by")
        sends.tap()
        let toFill = element("/bus/01/mix/01/level")
        XCTAssertTrue(toFill.appears(within: 2))
        XCTAssertEqual(toFill.label, "Fill")
        XCTAssertEqual(toFill.value as? String, "−∞ dB")
        XCTAssertTrue(element("/bus/01/mix/06/level").exists, "all six matrices")
        saveScreenshot("bus-sends")
    }

    /// The demo's Fill (Matrix 1) takes the main mix at 0 dB.
    func testTheMainSendsToTheMatrices() {
        launch()
        // The Main chip sits at the edge of a 375 pt screen: the engineer swipes the chip row first.
        app.buttons["Buses"].swipeLeft()
        app.buttons["Main"].tap()
        open("LR")
        app.buttons["Sends"].tap()
        let toFill = element("/main/st/mix/01/level")
        XCTAssertTrue(toFill.appears(within: 2))
        XCTAssertEqual(toFill.label, "Fill")
        XCTAssertEqual(toFill.value as? String, "0.0 dB")
    }

    func testSendsListBusesByName() {
        launch()
        open("Vox 1")
        app.buttons["Sends"].tap()
        let toMon1 = app.descendants(matching: .any)["/ch/13/mix/01/level"]
        XCTAssertTrue(toMon1.appears(within: 2))
        XCTAssertEqual(toMon1.label, "Mon 1")
        XCTAssertEqual(toMon1.value as? String, "0.0 dB")
    }

    /// A linked bus pair is one send, and its › opens the pan settings (mock H): the pan and Follow LR pan reach the
    /// desk, and while the send follows the LR pan its own pan can't be dragged.
    func testALinkedBusPairIsOneSendWithPanSettings() {
        desk.change("/config/buslink/5-6", 1)
        launch()
        open("Vox 1")
        app.buttons["Sends"].tap()
        let toPair = element("/ch/13/mix/05/level")
        XCTAssertTrue(toPair.appears(within: 2))
        XCTAssertEqual(toPair.label, "Bus 5-6")
        XCTAssertFalse(element("/ch/13/mix/06/level").exists, "the even bus is part of the pair's send")
        XCTAssertFalse(element("settings-/ch/13/mix/02/level").exists, "an even send has no tap point of its own")

        element("settings-/ch/13/mix/05/level").tap()
        let pan = element("/ch/13/mix/05/pan")
        XCTAssertTrue(pan.appears(within: 2))
        XCTAssertEqual(pan.value as? String, "C")
        drag(pan)
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/05/pan") != .float(0.5) }, "the pan reached the desk")

        app.switches["follow-/ch/13/mix/05/panFollow"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/05/panFollow") == .int(1) })
        XCTAssertTrue(eventually(within: 2) { !pan.isEnabled }, "the desk ignores the send's own pan now")
        saveScreenshot("send-sheet")
    }

    /// The demo links Gtr L/R (9-10): each side keeps its own send pan, as it keeps its own LR pan.
    func testALinkedSourceHasASendPanPerSide() {
        desk.change("/config/buslink/5-6", 1)
        launch()
        app.swipeUp()
        open("Gtr")
        app.buttons["Sends"].tap()
        element("settings-/ch/09/mix/05/level").tap()
        let left = element("/ch/09/mix/05/pan")
        XCTAssertTrue(left.appears(within: 2))
        XCTAssertEqual(left.label, "Pan · Gtr L")
        XCTAssertEqual(element("/ch/10/mix/05/pan").label, "Pan · Gtr R")
        saveScreenshot("send-sheet-pair")

        drag(left)
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/09/mix/05/pan") != .float(0.5) })
        XCTAssertEqual(desk.value("/ch/10/mix/05/pan"), .float(0.5), "the right side's pan stays its own")
    }

    private func drag(_ row: XCUIElement) {
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)))
    }

    func testFedByShowsWhoFeedsTheBus() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        app.buttons["Fed by"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["/ch/13/mix/01/level"].appears(within: 2))
        XCTAssertEqual(
            app.descendants(matching: .any)["/ch/13/mix/01/level"].value as? String, "0.0 dB")
        XCTAssertTrue(app.descendants(matching: .any)["/fxrtn/01/mix/01/level"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["/ch/20/mix/01/level"].exists, "unused inputs show too")
        XCTAssertFalse(app.switches["Show unused"].exists)
        saveScreenshot("task-16-fedby")
    }

    /// Like the overview, the demo's linked Gtr L/R (9-10) is one row, held by its odd side.
    func testFedByShowsALinkedPairAsOneRow() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        app.buttons["Fed by"].tap()
        let pair = element("/ch/09/mix/01/level")
        XCTAssertTrue(pair.appears(within: 2))
        XCTAssertEqual(pair.label, "Gtr")
        XCTAssertFalse(element("/ch/10/mix/01/level").exists, "the even side has no row of its own")
    }

    /// Unlinked on the desk while a finger holds the pair's send: the rows hold still under the finger (`SteadyRows`;
    /// XCUITest can't look during a hold) and split once it lifts, never stuck as they were.
    func testFedByRegroupsOnceTheFingerLifts() {
        launch()
        app.buttons["Buses"].tap()
        open("Mon 1")
        app.buttons["Fed by"].tap()
        let pair = element("/ch/09/mix/01/level")
        XCTAssertTrue(pair.appears(within: 2))
        // The 9th source sits below the screen's edge: scroll four rows, starting on a visible row.
        element("/ch/05/mix/01/level").press(forDuration: 0.05, thenDragTo: element("/ch/01/mix/01/level"))
        XCTAssertTrue(eventually(within: 2) { pair.isHittable })
        let desk = self.desk!
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) { desk.change("/config/chlink/9-10", 0) }
        pair.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(
                forDuration: 0.05, thenDragTo: pair.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)),
                withVelocity: .slow, thenHoldForDuration: 2)
        XCTAssertTrue(
            eventually(within: 3) { self.element("/ch/10/mix/01/level").exists }, "the pair split once lifted")
        XCTAssertNotEqual(element("/ch/09/mix/01/level").value as? String, "−∞ dB", "the drag moved the send")
    }

    /// A matrix is fed by the buses and the mains; the demo's Fill takes the main mix at 0 dB.
    func testMatrixIsFedByTheMains() {
        launch()
        // The last chip sits past the edge of a 375 pt screen: the engineer swipes the chip row first.
        app.buttons["Buses"].swipeLeft()
        app.buttons["Matrix"].tap()
        open("Fill")
        app.buttons["Fed by"].tap()
        let fromMain = element("/main/st/mix/01/level")
        XCTAssertTrue(fromMain.appears(within: 2))
        XCTAssertEqual(fromMain.label, "LR")
        XCTAssertEqual(fromMain.value as? String, "0.0 dB")
        XCTAssertTrue(element("/bus/01/mix/01/level").exists)
        XCTAssertFalse(element("/ch/01/mix/01/level").exists, "inputs feed buses, not matrices")
        saveScreenshot("matrix-fedby")
    }
}

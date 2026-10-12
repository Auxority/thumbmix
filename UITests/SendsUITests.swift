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

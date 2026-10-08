import XCTest

/// Sends to the matrices from a bus or a main (mock B): the input's Sends tab, one row per matrix.
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
}

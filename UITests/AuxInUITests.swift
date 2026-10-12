import XCTest

/// Aux ins get Input · EQ · Sends like an input (doc p.28), without the gate, comp, delay and low cut they lack.
@MainActor
final class AuxInUITests: DeskUITestCase {
    private func openAux1() {
        app.buttons["Aux"].tap()
        open("Aux 1")
    }

    /// The demo's aux ins are the desk's line jacks: no preamp, so the Input tab shows Trim alone.
    func testAuxGetsInputEQAndSendsTabs() {
        launch()
        openAux1()
        for tab in ["Mix", "Input", "EQ", "Sends"] { XCTAssertTrue(app.buttons[tab].exists, tab) }
        XCTAssertFalse(app.buttons["Gate"].exists)
        XCTAssertFalse(app.buttons["Comp"].exists)

        app.buttons["Input"].tap()
        XCTAssertTrue(element("/auxin/01/preamp/trim").appears(within: 2))
        XCTAssertFalse(app.staticTexts["No preamp: this channel reads from an internal source."].exists)

        app.buttons["EQ"].tap()
        XCTAssertTrue(element("/auxin/01/eq/1/f").appears(within: 2))
        XCTAssertFalse(app.buttons["LC"].exists, "an aux in has no low cut")
        saveScreenshot("aux-eq")

        app.buttons["Sends"].tap()
        XCTAssertTrue(element("/auxin/01/mix/01/level").appears(within: 2))
    }

    /// Routed from Kick's preamp, aux 1 shows its Gain and 48V, and the 48V alert names Kick.
    func testAuxOnAnInputsPreampShowsGainAnd48V() {
        desk.change("/-ha/32/index", 32)
        launch()
        openAux1()
        app.buttons["Input"].tap()
        XCTAssertTrue(element("/headamp/032/gain").appears(within: 2))
        XCTAssertTrue(app.staticTexts["Shares an input with Kick"].exists)
        saveScreenshot("aux-input-preamp")

        app.buttons["toggle-/headamp/032/phantom"].tap()
        let alert = app.alerts["Turn on 48V for Aux 1?"]
        XCTAssertTrue(alert.appears(within: 2))
        XCTAssertTrue(alert.staticTexts["Also powers Kick (same input)."].exists)
        alert.buttons["Cancel"].tap()
    }
}

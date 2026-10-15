import XCTest

/// FX returns get EQ · Sends (doc p.30): a 4-band EQ and 16 bus sends, without the preamp, gate and comp they lack.
@MainActor
final class FXReturnUITests: DeskUITestCase {
    func testFXReturnGetsEQAndSendsTabs() {
        launchAndOpen("Rev L", group: "FX")
        for tab in ["Mix", "EQ", "Sends"] { XCTAssertTrue(app.buttons[tab].exists, tab) }
        for tab in ["Input", "Gate", "Comp"] { XCTAssertFalse(app.buttons[tab].exists, tab) }

        app.buttons["EQ"].tap()
        let band = element("/fxrtn/01/eq/1/f")
        XCTAssertTrue(band.appears(within: 2))
        XCTAssertTrue(eventually(within: 2) { band.isEnabled }, "read when the tab opens")
        XCTAssertFalse(app.buttons["LC"].exists, "an FX return has no low cut")
        saveScreenshot("fx-return-eq")

        app.buttons["Sends"].tap()
        let send = element("/fxrtn/01/mix/01/level")
        XCTAssertTrue(send.appears(within: 2))
        XCTAssertTrue(eventually(within: 2) { send.isEnabled }, "read when the tab opens")
        saveScreenshot("fx-return-sends")
    }
}

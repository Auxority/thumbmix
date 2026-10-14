import XCTest

/// A Fed by row's tall › opens the send sheet, as on Sends (2026-10-14). Its title links both strips: the source
/// opens on Sends, the bus already on screen only closes the sheet. The mains have no › (`MainsFedByUITests`).
@MainActor
final class FedBySendSheetUITests: DeskUITestCase {
    private func openVoxSendFromMon1() {
        app.buttons["Buses"].tap()
        open("Mon 1")
        app.buttons["Fed by"].tap()
        let settings = element("settings-/ch/13/mix/01/level")
        XCTAssertTrue(settings.appears(within: 2))
        settings.tap()
        XCTAssertTrue(app.buttons["Open Vox 1"].appears(within: 2))
    }

    /// The demo's Mon 1-2 are unlinked: they share a tap point, so the sheet shows both, as from Vox 1's Sends.
    func testAFedByRowsSettingsSetTheTapPoint() {
        launch()
        openVoxSendFromMon1()
        XCTAssertTrue(app.buttons["Open Mon 1"].exists)
        XCTAssertTrue(app.buttons["Open Mon 2"].exists)
        XCTAssertTrue(app.staticTexts["Before fader"].exists, "read with the tab")
        saveScreenshot("fedby-send-sheet")

        element("tap-Fader").tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(4) })
    }

    func testTheTitleOpensTheSourceOnItsSendsAndTheBusOnlyCloses() {
        launch()
        openVoxSendFromMon1()
        app.buttons["Open Mon 1"].tap()
        XCTAssertTrue(eventually(within: 2) { !self.app.buttons["Open Vox 1"].exists }, "the sheet closed")
        XCTAssertTrue(app.buttons["Fed by"].isSelected, "still Mon 1's Fed by, nothing pushed")
        XCTAssertTrue(app.staticTexts["Bus 1"].exists)

        element("settings-/ch/13/mix/01/level").tap()
        let vox = app.buttons["Open Vox 1"]
        XCTAssertTrue(vox.appears(within: 2))
        vox.tap()
        XCTAssertTrue(app.staticTexts["Ch 13"].appears(within: 3), "Vox 1's own screen")
        XCTAssertTrue(app.buttons["Sends"].isSelected, "where its send to Mon 1 is a row")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Bus 1"].appears(within: 3))
        XCTAssertTrue(app.buttons["Fed by"].isSelected, "back where it left")
    }
}

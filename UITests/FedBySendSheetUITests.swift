import XCTest

/// A Fed by row's tall › opens the send sheet, as on Sends (2026-10-14). Its title links both strips: the source
/// opens on Sends, the bus already on screen only closes the sheet. The mains have no › (`SendsUITests`).
@MainActor
final class FedBySendSheetUITests: DeskUITestCase {
    private func openVoxSendFromMon1() {
        let settings = element("settings-/ch/13/mix/01/level")
        XCTAssertTrue(settings.appears(within: 2))
        settings.tap()
        XCTAssertTrue(app.buttons["Open Vox 1"].appears(within: 2))
    }

    /// The demo's Mon 1-2 are unlinked: they share a tap point, so the sheet shows both, as from Vox 1's Sends. The
    /// title's bus only closes the sheet, its source opens on Sends. Like the fold sheets, when contact is lost the
    /// sheet shows its own banner over the tab's, and Done still closes it.
    func testAFedByRowsSettingsSetTheTapPoint() {
        launchAndOpen("Mon 1", group: "Buses", tab: "Fed by")
        openVoxSendFromMon1()
        XCTAssertTrue(app.buttons["Open Mon 1"].exists)
        XCTAssertTrue(app.buttons["Open Mon 2"].exists)
        XCTAssertTrue(app.staticTexts["Before fader"].exists, "read with the tab")
        saveScreenshot("fedby-send-sheet")
        element("tap-Fader").tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(4) }, "the tap point")

        app.buttons["Open Mon 1"].tap()
        XCTAssertTrue(eventually(within: 2) { !self.app.buttons["Open Vox 1"].exists }, "the sheet closed")
        XCTAssertTrue(app.buttons["Fed by"].isSelected, "still Mon 1's Fed by, nothing pushed")
        XCTAssertTrue(app.staticTexts["Bus 1"].exists)

        openVoxSendFromMon1()
        app.buttons["Open Vox 1"].tap()
        XCTAssertTrue(app.staticTexts["Ch 13"].appears(within: 3), "Vox 1's own screen")
        XCTAssertTrue(app.buttons["Sends"].isSelected, "where its send to Mon 1 is a row")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Bus 1"].appears(within: 3))
        XCTAssertTrue(app.buttons["Fed by"].isSelected, "back where it left")

        // Last: the desk stays silent.
        openVoxSendFromMon1()
        let tap = element("tap-Fader")
        XCTAssertTrue(eventually(within: 2) { tap.isEnabled })
        desk.goSilent()
        let banners = app.staticTexts.matching(NSPredicate(format: "label == %@", "Disconnected — retrying"))
        let sheetTop = app.buttons["Open Vox 1"].frame.maxY
        XCTAssertTrue(
            eventually(within: 8) { banners.allElementsBoundByIndex.contains { $0.frame.minY >= sheetTop - 1 } },
            "the sheet's own banner, under its title, not the tab's behind it")
        XCTAssertFalse(tap.isEnabled)
        XCTAssertFalse(app.buttons["Open Vox 1"].isEnabled, "no opening strips while the tab is disabled either")
        XCTAssertTrue(app.buttons["Done"].isEnabled, "the sheet still closes")
    }
}

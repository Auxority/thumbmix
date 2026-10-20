import XCTest

/// A strip's DCAs and mute groups in its edit sheet, sent with the name on Done (S1, 2026-10-19). The demo desk has
/// Kick (Ch 1) on DCA 1 and in mute group 1, every group off.
@MainActor
final class StripGroupsSheetUITests: DeskUITestCase {
    private func openTheSheet() {
        app.buttons["edit-strip"].tap()
        XCTAssertTrue(element("sheet-dca-2").appears(within: 3))
    }

    /// Ticks reach the desk only on Done; Cancel leaves the groups alone. Joining a group that's on mutes the strip
    /// there and then: the sheet says so before Done, naming the strip as it will be called after Done. The red border
    /// has words for VoiceOver too, a chip says which kind of group it is, and the icon's "Icon" is read once.
    func testDoneSendsTheTickedGroups() {
        desk.change("/config/mute/2", 1)
        launchAndOpen("Kick")
        openTheSheet()
        element("sheet-dca-2").tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Mix"].appears(within: 3))
        XCTAssertEqual(desk.value("/ch/01/grp/dca"), .int(1), "Cancel leaves the groups alone")

        openTheSheet()
        XCTAssertEqual(element("sheet-mute-2").label, "Mute group 2, on")
        XCTAssertEqual(element("sheet-mute-3").label, "Mute group 3")
        XCTAssertEqual(element("sheet-dca-2").label, "DCA 2, Band")
        XCTAssertFalse(app.staticTexts["Icon"].exists || app.staticTexts["ICON"].exists, "the tile says Icon")
        XCTAssertFalse(element("mutes-on-done").exists)
        let field = app.textFields["strip-name"]
        field.tap()
        field.typeText("er")
        element("sheet-dca-2").tap()
        element("sheet-mute-2").tap()
        let warning = element("mutes-on-done")
        XCTAssertTrue(warning.appears(within: 2))
        XCTAssertTrue(warning.label.contains("Kicker") && warning.label.contains("2"), warning.label)
        XCTAssertEqual(element("sheet-dca-2").value as? String, "Assigned")
        XCTAssertEqual(desk.value("/ch/01/grp/dca"), .int(1), "nothing reaches the desk before Done")
        saveScreenshot("strip-groups-sheet")

        app.buttons["Done"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/grp/dca") == .int(0b11) })
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/grp/mute") == .int(0b11) })
    }

    /// A pair's sheet has two name fields; every chip still fits the iPhone SE without scrolling. The desk holds
    /// only Gtr L on DCA 2: the chip says which side, once.
    func testAPairFitsTheSE() {
        desk.change("/ch/10/grp/dca", 0)
        launchAndOpen("Gtr")
        openTheSheet()
        let chip = element("sheet-dca-2")
        XCTAssertEqual(chip.value as? String, "Left side only")
        XCTAssertEqual(chip.label, "DCA 2, Band")
        saveScreenshot("strip-groups-sheet-half-pair")
        XCTAssertTrue(element("sheet-mute-6").isHittable, "every chip fits the SE")
        saveScreenshot("strip-groups-sheet-pair")
    }
}

import XCTest

/// DCAs: renaming one (or cancelling it) and the channels it holds.
@MainActor
final class DCAUITests: DeskUITestCase {
    func testRenamingADCAReachesTheOverview() {
        launchAndOpen("Band", group: "DCA")
        app.buttons["edit-strip"].tap()
        let field = app.textFields["strip-name"]
        XCTAssertTrue(field.appears(within: 3))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "Rhythm section")
        XCTAssertEqual(field.value as? String, "Rhythm secti", "the desk stores 12 characters")
        app.buttons["color-green"].tap()
        saveScreenshot("edit-strip")
        // The icon opens its grid on a page of its own; picking one comes back with it in the tile.
        app.buttons["icon-tile"].tap()
        XCTAssertTrue(app.navigationBars["Icon"].appears(within: 3))
        let search = app.textFields["icon-search"]
        search.tap()
        search.typeText("kit")
        app.buttons["icon-11"].tap()
        XCTAssertTrue(eventually(within: 3) { self.app.buttons["icon-tile"].value as? String == "Drum Kit" })
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Rhythm secti"].appears(within: 3))
        XCTAssertTrue(
            eventually(within: 2) { self.desk.value("/dca/2/config/name") == .string("Rhythm secti") },
            "the name reached the desk")
        XCTAssertEqual(desk.value("/dca/2/config/color"), .int(2), "green")
        XCTAssertEqual(desk.value("/dca/2/config/icon"), .int(11), "Drum Kit")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Rhythm secti"].appears(within: 3))
    }

    /// Every page of the picker is saved to build/screens, so the drawings can be checked as iOS renders them.
    func testIconPickerScrollsToTheLastIcon() {
        launchAndOpen("Vox", group: "DCA")
        app.buttons["edit-strip"].tap()
        XCTAssertTrue(app.buttons["icon-tile"].appears(within: 3))
        XCTAssertFalse(app.buttons["icon-2"].exists, "the grid is on its own page, not in the sheet")
        app.buttons["icon-tile"].tap()
        XCTAssertTrue(app.buttons["icon-2"].appears(within: 3))
        for page in 1...2 {
            saveScreenshot("icon-picker-\(page)")
            app.swipeUp()
        }
        saveScreenshot("icon-picker-3")
        XCTAssertTrue(app.buttons["icon-74"].isHittable, "the last icon, Smiley, scrolls into reach")
    }

    func testCancelLeavesTheDeskUnchanged() {
        launchAndOpen("Vox", group: "DCA")
        app.buttons["edit-strip"].tap()
        let field = app.textFields["strip-name"]
        XCTAssertTrue(field.appears(within: 3))
        field.tap()
        field.typeText("X")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Vox"].appears(within: 3))
        XCTAssertFalse(app.staticTexts["VoxX"].exists)
        XCTAssertEqual(desk.value("/dca/3/config/name"), .string("Vox"), "nothing reached the desk")
    }

    /// Every strip is listed, assigned or not: Bass (Ch 8) is on DCA 2, not Drums.
    func testDCAMembers() {
        launchAndOpen("Drums", group: "DCA")
        app.buttons["Members"].tap()
        XCTAssertTrue(element("assign-/ch/02").appears(within: 3))
        XCTAssertEqual(element("assign-/ch/02").value as? String, "Assigned", "Snare")
        XCTAssertEqual(element("assign-/ch/08").value as? String, "Not assigned", "Bass")
        saveScreenshot("dca-members")
    }

    /// A tap assigns at once and keeps the strip's other DCAs; a second tap takes it off again.
    func testTheChipAssignsAndUnassigns() {
        launchAndOpen("Drums", group: "DCA")
        app.buttons["Members"].tap()
        let bass = element("assign-/ch/08")
        XCTAssertTrue(bass.appears(within: 3))
        bass.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/08/grp/dca") == .int(0b011) })
        XCTAssertTrue(eventually(within: 2) { bass.value as? String == "Assigned" })
        bass.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/08/grp/dca") == .int(0b010) })
    }

    /// The linked guitars (Ch 9-10) are one row, and its chip assigns both sides.
    func testALinkedPairIsAssignedAsOne() {
        launchAndOpen("Drums", group: "DCA")
        app.buttons["Members"].tap()
        let gtr = element("assign-/ch/09")
        XCTAssertTrue(gtr.appears(within: 3))
        XCTAssertFalse(element("assign-/ch/10").exists)
        gtr.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/10/grp/dca") == .int(0b011) })
        XCTAssertEqual(desk.value("/ch/09/grp/dca"), .int(0b011))
    }

    /// Laid out like an overview row: the name block with its stripe, then the chip on the right, where the overview's
    /// mute sits, nearest the thumb (S4, 2026-10-17).
    func testTheChipSitsRightOfTheName() {
        launchAndOpen("Drums", group: "DCA")
        app.buttons["Members"].tap()
        let name = element("member-/ch/02")
        let chip = element("assign-/ch/02")
        XCTAssertTrue(chip.appears(within: 3))
        XCTAssertLessThan(name.frame.maxX, chip.frame.minX)
        saveScreenshot("dca-member-stripes")
    }

    func testAMembersNameOpensItsStrip() {
        launchAndOpen("Drums", group: "DCA")
        app.buttons["Members"].tap()
        let snare = element("member-/ch/02")
        XCTAssertTrue(snare.appears(within: 3))
        snare.tap()
        XCTAssertTrue(app.navigationBars["Ch 2"].appears(within: 3))
    }
}

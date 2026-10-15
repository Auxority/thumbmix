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
        let search = app.textFields["icon-search"]
        search.tap()
        search.typeText("kit")
        app.buttons["icon-11"].tap()
        saveScreenshot("edit-strip")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Rhythm secti"].appears(within: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Rhythm secti"].appears(within: 3))
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
    }

    func testDCAMembers() {
        launchAndOpen("Drums", group: "DCA")
        app.buttons["Members"].tap()
        XCTAssertTrue(element("member-/ch/02").exists, "Snare")
        XCTAssertFalse(element("member-/ch/08").exists, "Bass")
    }
}

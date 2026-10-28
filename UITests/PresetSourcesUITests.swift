import XCTest

/// The Sources page: Add offers a folder, a file or a web address; a web address is added, refused when it isn't plain
/// HTTPS, or removed. Reading a source stays in Core tests (a stubbed session); `-isolatedPresets` starts with no
/// sources, and the one added here is on `.invalid`, which never resolves, so nothing here depends on the web.
@MainActor
final class PresetSourcesUITests: DeskUITestCase {
    func testAnAddressIsAddedRefusedOrRemoved() {
        launch(["-isolatedPresets", "YES"])
        open("Kick")
        app.buttons["edit-strip"].tap()
        let row = element("presets-row")
        XCTAssertTrue(row.appears(within: 3))
        row.tap()
        let sources = element("presets-sources")
        XCTAssertTrue(sources.appears(within: 3))
        sources.tap()
        // The default source isn't offered back: its address is in the README, to add like any other.
        XCTAssertTrue(element("sources-add").appears(within: 3))
        XCTAssertFalse(element("sources-add-default").exists)

        addAddress("http://example.invalid/index.json")
        let notice = app.alerts["Presets"]
        XCTAssertTrue(notice.appears(within: 3))
        XCTAssertTrue(notice.staticTexts["The address must be https:// with no name, password or query."].exists)
        notice.buttons["OK"].tap()
        XCTAssertTrue(eventually(within: 3) { !self.app.alerts.firstMatch.exists })

        addAddress("https://example.invalid/presets/index.json")
        let source = element("source-example.invalid")
        XCTAssertTrue(source.appears(within: 3))
        saveScreenshot("preset-sources")
        source.swipeLeft()
        app.buttons["Remove"].tap()
        XCTAssertTrue(eventually(within: 3) { !source.exists }, "removed")
    }

    /// Add opens a menu of the three kinds; Folder and File open the Files picker, which XCUITest can't drive.
    private func addAddress(_ address: String) {
        element("sources-add").tap()
        let web = app.buttons["sources-add-web"]
        XCTAssertTrue(web.appears(within: 3))
        XCTAssertTrue(app.buttons["sources-add-folder"].exists)
        XCTAssertTrue(app.buttons["sources-add-file"].exists)
        saveScreenshot("preset-sources-add")
        web.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.appears(within: 3))
        field.typeText(address)
        app.alerts.buttons["Add"].tap()
    }
}

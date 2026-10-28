import XCTest

/// The Sources page: adding a web address, refusing one that isn't plain HTTPS, and removing one. Reading a source
/// stays in Core tests (a stubbed session); `-isolatedPresets` starts with no sources, so nothing here needs the web.
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

    private func addAddress(_ address: String) {
        element("sources-add").tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.appears(within: 3))
        field.typeText(address)
        app.alerts.buttons["Add"].tap()
    }
}

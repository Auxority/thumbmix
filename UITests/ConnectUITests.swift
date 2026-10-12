import XCTest

@MainActor
final class ConnectUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The decimal keypad shows the region's separator, so in the Netherlands it only types commas.
    func testCommasFromADutchKeypadBecomeDots() {
        let app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", "", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launch()

        let field = app.textFields["console-ip"]
        XCTAssertTrue(field.appears(within: 5))
        field.tap()
        // One key at a time: the field turns each comma into a dot as it arrives, and XCUITest's fast typing
        // dropped a key while that ran.
        for key in "192,168,1,50" { field.typeText(String(key)) }
        XCTAssertEqual(field.value as? String, "192.168.1.50")
        XCTAssertTrue(app.buttons["Connect"].isEnabled)
    }

    func testRejectsInvalidAddress() {
        let app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", ""] + fixedLocale
        app.launch()

        let field = app.textFields["console-ip"]
        XCTAssertTrue(field.appears(within: 5))
        field.tap()
        field.typeText("192.168.1")
        XCTAssertFalse(app.buttons["Connect"].isEnabled)
        saveScreenshot("connect-disabled")
        assertLabelContrasts(app.buttons["Connect"])
        assertFillIsBlack(app.buttons["Connect"])
    }

    /// The app tint is white, so the prominent button drew its default white label on a white fill.
    func testEnabledConnectLabelIsVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", ""] + fixedLocale
        app.launch()

        let field = app.textFields["console-ip"]
        XCTAssertTrue(field.appears(within: 5))
        field.tap()
        field.typeText("10.0.0.1")
        let connect = app.buttons["Connect"]
        XCTAssertTrue(connect.isEnabled)
        saveScreenshot("connect-enabled")
        assertLabelContrasts(connect)
    }

    func testConnectsToFakeAndSyncs() {
        guard let desk = TestDesk.start(for: self) else { return }
        let app = XCUIApplication()
        app.launchArguments = desk.connect + fixedLocale
        app.launch()

        XCTAssertTrue(app.buttons["Kick"].appears(within: 15))
    }
}

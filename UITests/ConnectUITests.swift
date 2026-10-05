import XCTest

@MainActor
final class ConnectUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testRejectsInvalidAddress() {
        let app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", ""]
        app.launch()

        let field = app.textFields["console-ip"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("192.168.1")
        XCTAssertFalse(app.buttons["Connect"].isEnabled)
    }

    func testConnectsToFakeAndSyncs() {
        let app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", "127.0.0.1"]
        app.launch()

        XCTAssertTrue(app.buttons["Kick"].waitForExistence(timeout: 15))
    }
}

import XCTest

/// iOS wraps toolbar buttons in grey glass; on an OLED screen they're glass tinted black instead.
@MainActor
final class BlackButtonsUITests: DeskUITestCase {
    /// The overview's Disconnect, then the edit sheet's Cancel and Done.
    func testToolbarButtonsAreBlack() {
        launch()
        saveScreenshot("overview-buttons")
        XCTAssertFalse(app.navigationBars.staticTexts["Thumbmix"].exists, "the overview has no title")
        assertFillIsBlack(app.buttons["Disconnect"])
        assertNotSqueezed(app.buttons["Disconnect"])

        open("Kick")
        app.buttons["edit-strip"].tap()
        XCTAssertTrue(app.buttons["Done"].appears(within: 3))
        XCTAssertTrue(app.buttons["Done"].settles(within: 3))
        saveScreenshot("edit-strip-buttons")
        assertFillIsBlack(app.buttons["Cancel"])
        assertFillIsBlack(app.buttons["Done"])
        assertNotSqueezed(app.buttons["Cancel"])
        assertNotSqueezed(app.buttons["Done"])
    }

    /// iOS 27's bar shrank the capsules to one letter ("D" for Disconnect); the whole word needs at least 8 pt per letter plus the padding.
    private func assertNotSqueezed(_ button: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let needed = CGFloat(button.label.count) * 8 + 32
        XCTAssertGreaterThanOrEqual(
            button.frame.width, needed, "\(button.label) is squeezed to \(button.frame.width) pt", file: file, line: line)
    }
}

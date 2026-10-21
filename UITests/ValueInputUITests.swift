import XCTest

/// Holding a slider row types its value in the system alert.
@MainActor
final class ValueInputUITests: DeskUITestCase {
    /// The alert says the range. Text that isn't a value, and a number past either end, reopen the alert saying so,
    /// text kept; neither reaches the desk ("100" on a fader must not set +10 dB). A value in range is set.
    /// Where a typed value lands on the desk's grid (1k → 990.9 Hz) is `ValueInputTests` in Core.
    func testHoldingAFaderTypesItsValue() {
        launchAndOpen("Kick")
        let fader = element("/ch/01/mix/fader")
        XCTAssertTrue(fader.appears(within: 2))
        let before = fader.value as? String
        let deskBefore = desk.value("/ch/01/mix/fader")
        fader.press(forDuration: 0.8)
        let alert = app.alerts["Fader"]
        XCTAssertTrue(alert.appears(within: 2))
        XCTAssertTrue(alert.staticTexts["−∞ dB to +10.0 dB"].exists, "the alert says the range")

        alert.textFields.firstMatch.typeText("abc")
        alert.buttons["Set"].tap()
        let again = app.alerts["Fader"]
        XCTAssertTrue(again.staticTexts["“abc” isn't a value. −∞ dB to +10.0 dB"].appears(within: 3))
        let field = again.textFields.firstMatch
        XCTAssertEqual(field.value as? String, "abc", "the text stays to be fixed")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "100")
        again.buttons["Set"].tap()
        let third = app.alerts["Fader"]
        XCTAssertTrue(third.staticTexts["“100” is out of range. −∞ dB to +10.0 dB"].appears(within: 3))
        XCTAssertEqual(third.textFields.firstMatch.value as? String, "100", "the text stays to be fixed")
        XCTAssertEqual(fader.value as? String, before, "nothing reached the screen")
        XCTAssertEqual(desk.value("/ch/01/mix/fader"), deskBefore, "nothing reached the desk")

        third.textFields.firstMatch.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "-6")
        third.buttons["Set"].tap()
        XCTAssertTrue(eventually(within: 2) { fader.value as? String == "−6.0 dB" })
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/mix/fader") != deskBefore }, "set on the desk")
        saveScreenshot("type-a-value")
    }
}

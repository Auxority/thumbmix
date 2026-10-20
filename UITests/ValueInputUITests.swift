import XCTest

/// Holding a slider row types its value in the system alert.
@MainActor
final class ValueInputUITests: DeskUITestCase {
    /// The alert says the range. Text that isn't a value, and a number past either end, reopen the alert saying so,
    /// text kept; neither reaches the desk ("100" on a fader must not set +10 dB). A value in range is set.
    /// Where a typed value lands on the desk's grid (1k → 991 Hz) is `ValueInputTests` in Core.
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

    /// One speed wherever the finger is: the finer speeds off the row came too late for a small nudge, so exact
    /// values are typed instead (2026-10-12). The row only claims a mostly sideways drag, and XCUITest drags in a
    /// straight line, so the finger leaves the row on a shallow slant.
    func testDraggingAwayFromTheRowKeepsItsSpeed() {
        launchAndOpen("Kick", tab: "Input")
        let trim = element("/ch/01/preamp/trim")
        XCTAssertTrue(trim.appears(within: 2))
        let start = trim.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 160, dy: 0)))
        let alongTheRow = decibels(trim)
        trim.doubleTap()
        XCTAssertTrue(eventually(within: 2) { self.decibels(trim) == 0 })
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 160, dy: 150)))
        let farBelow = decibels(trim)
        XCTAssertGreaterThan(alongTheRow, 0)
        XCTAssertEqual(farBelow, alongTheRow, accuracy: 0.5, "\(farBelow) dB far below vs \(alongTheRow) dB along")
    }

    /// "+6.0 dB" or "−3.5 dB" as a number.
    private func decibels(_ row: XCUIElement) -> Double {
        let text = (row.value as? String ?? "").replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: " dB", with: "").replacingOccurrences(of: "+", with: "")
        return Double(text) ?? .nan
    }
}

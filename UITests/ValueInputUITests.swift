import XCTest

/// Holding a slider row types its value in the system alert; dragging away from the row drags finer.
@MainActor
final class ValueInputUITests: DeskUITestCase {
    private func holdKicksFader() -> (fader: XCUIElement, alert: XCUIElement) {
        launch()
        open("Kick")
        let fader = element("/ch/01/mix/fader")
        XCTAssertTrue(fader.appears(within: 2))
        fader.press(forDuration: 0.8)
        let alert = app.alerts["Fader"]
        XCTAssertTrue(alert.appears(within: 2))
        return (fader, alert)
    }

    func testHoldingAFaderTypesItsValue() {
        let (fader, alert) = holdKicksFader()
        XCTAssertTrue(alert.staticTexts["−∞ dB to +10.0 dB"].exists, "the alert says the range")
        alert.textFields.firstMatch.typeText("-6")
        alert.buttons["Set"].tap()
        XCTAssertTrue(eventually(within: 2) { fader.value as? String == "−6.0 dB" })
        saveScreenshot("type-a-value")
    }

    /// Text that isn't a value reopens the alert saying so, text kept; a number past the end lands on it.
    func testOnlyAValueCanBeSetAndItStaysInRange() {
        let (fader, alert) = holdKicksFader()
        alert.textFields.firstMatch.typeText("abc")
        alert.buttons["Set"].tap()
        let again = app.alerts["Fader"]
        XCTAssertTrue(again.staticTexts["“abc” isn't a value. −∞ dB to +10.0 dB"].appears(within: 3))
        let field = again.textFields.firstMatch
        XCTAssertEqual(field.value as? String, "abc", "the text stays to be fixed")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "100")
        again.buttons["Set"].tap()
        XCTAssertTrue(eventually(within: 2) { fader.value as? String == "+10.0 dB" })
    }

    /// The desk keeps 201 frequency steps: 1 kHz lands on the nearest, 991 Hz, and the row shows that.
    func testAFrequencySnapsToTheDesksStep() {
        launch()
        open("Kick")
        app.buttons["EQ"].tap()
        let frequency = element("/ch/01/eq/1/f")
        XCTAssertTrue(frequency.appears(within: 2))
        frequency.press(forDuration: 0.8)
        let alert = app.alerts["Freq"]
        XCTAssertTrue(alert.appears(within: 2))
        alert.textFields.firstMatch.typeText("1k")
        alert.buttons["Set"].tap()
        XCTAssertTrue(eventually(within: 2) { frequency.value as? String == "991 Hz" })
    }

    /// The same sideways travel moves the value less when the finger strays below the row. The row only claims a
    /// mostly sideways drag, and XCUITest drags in a straight line, so the finger leaves the row on a shallow slant.
    func testDraggingAwayFromTheRowIsFiner() {
        launch()
        open("Kick")
        app.buttons["Input"].tap()
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
        XCTAssertLessThan(farBelow, alongTheRow * 0.9, "\(farBelow) dB far below vs \(alongTheRow) dB along")
    }

    /// "+6.0 dB" or "−3.5 dB" as a number.
    private func decibels(_ row: XCUIElement) -> Double {
        let text = (row.value as? String ?? "").replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: " dB", with: "").replacingOccurrences(of: "+", with: "")
        return Double(text) ?? .nan
    }
}

import XCTest

/// What VoiceOver and larger text get: which colour is selected, rows that grow. Which group pill is selected is in
/// `PillBarUITests`, which strip an overview control belongs to in `OverviewUITests`.
@MainActor
final class AccessibilityUITests: DeskUITestCase {
    /// Each swatch says its colour and whether it is picked. The inverted colours are a second row of swatches, not a
    /// switch (B, 2026-10-17).
    func testColourSwatchesSayTheirNameAndWhichIsSelected() {
        launchAndOpen("Kick")
        app.buttons["edit-strip"].tap()
        let red = app.buttons["color-red"]
        XCTAssertTrue(red.appears(within: 2))
        XCTAssertEqual(red.label, "Red")
        XCTAssertTrue(red.isSelected, "the demo desk colours Kick red")
        XCTAssertFalse(app.buttons["color-green"].isSelected)
        XCTAssertEqual(app.buttons["color-off"].label, "No colour")

        let invertedRed = app.buttons["color-red-inverted"]
        XCTAssertEqual(invertedRed.label, "Red")
        XCTAssertEqual(invertedRed.value as? String, "Inverted")
        XCTAssertFalse(app.switches["Inverted"].exists, "not a switch")
        invertedRed.tap()
        XCTAssertTrue(eventually(within: 2) { invertedRed.isSelected })
        XCTAssertFalse(red.isSelected)
        saveScreenshot("colour-swatches")
    }

    /// The overview's rows and a DCA's member rows grow with the text size. A row is at least 48 pt at any size, so
    /// only taller shows the text grew.
    func testRowsGrowWithLargerText() {
        launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let fader = element("/ch/01/mix/fader")
        XCTAssertTrue(fader.appears(within: 5))
        XCTAssertGreaterThan(fader.frame.height, 70, "an overview row")
        saveScreenshot("dynamic-type-overview")

        app.buttons["DCA"].tap()
        open("Drums")
        app.buttons["Members"].tap()
        let snare = element("member-/ch/02")
        XCTAssertTrue(snare.appears(within: 3))
        XCTAssertGreaterThan(snare.frame.height, 60, "a DCA member row")
    }
}

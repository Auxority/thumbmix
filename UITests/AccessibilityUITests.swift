import XCTest

/// What VoiceOver and larger text get: which choice is selected, which strip a control belongs to, rows that grow.
@MainActor
final class AccessibilityUITests: DeskUITestCase {
    func testGroupPillsSayWhichIsSelected() {
        launch()
        XCTAssertTrue(app.buttons["Inputs"].appears(within: 5))
        XCTAssertTrue(app.buttons["Inputs"].isSelected)
        app.buttons["Buses"].tap()
        XCTAssertTrue(eventually(within: 2) { self.app.buttons["Buses"].isSelected })
        XCTAssertFalse(app.buttons["Inputs"].isSelected)
    }

    /// Forty rows of "Fader" and "Mute" tell a VoiceOver user nothing; each control says its strip.
    func testOverviewControlsNameTheirStrip() {
        launch()
        let fader = element("/ch/01/mix/fader")
        XCTAssertTrue(fader.appears(within: 5))
        XCTAssertEqual(fader.label, "Kick fader")
        let mute = app.buttons["mute-/ch/01/mix/on"]
        XCTAssertEqual(mute.label, "Mute Kick")
        mute.tap()
        XCTAssertTrue(eventually(within: 2) { mute.label == "Unmute Kick" })
    }

    func testColourSwatchesSayTheirNameAndWhichIsSelected() {
        launchAndOpen("Kick")
        app.buttons["edit-strip"].tap()
        let red = app.buttons["color-red"]
        XCTAssertTrue(red.appears(within: 2))
        XCTAssertEqual(red.label, "Red")
        XCTAssertTrue(red.isSelected, "the demo desk colours Kick red")
        XCTAssertFalse(app.buttons["color-green"].isSelected)
        XCTAssertEqual(app.buttons["color-off"].label, "No colour")
    }

    /// The inverted colours are a second row of swatches, not a switch (B, 2026-10-17).
    func testInvertedColoursAreTheirOwnSwatches() {
        launchAndOpen("Kick")
        app.buttons["edit-strip"].tap()
        let invertedRed = app.buttons["color-red-inverted"]
        XCTAssertTrue(invertedRed.appears(within: 2))
        XCTAssertEqual(invertedRed.label, "Red")
        XCTAssertEqual(invertedRed.value as? String, "Inverted")
        XCTAssertFalse(app.switches["Inverted"].exists)
        invertedRed.tap()
        XCTAssertTrue(eventually(within: 2) { invertedRed.isSelected })
        XCTAssertFalse(app.buttons["color-red"].isSelected)
        saveScreenshot("colour-swatches")
    }

    func testDCAMemberRowsGrowWithLargerText() {
        launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.buttons["DCA"].tap()
        open("Drums")
        app.buttons["Members"].tap()
        let snare = element("member-/ch/02")
        XCTAssertTrue(snare.appears(within: 3))
        // The row is at least 48 pt at any size: only taller shows the text grew.
        XCTAssertGreaterThan(snare.frame.height, 60)
    }
}

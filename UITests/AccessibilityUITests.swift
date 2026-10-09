import XCTest

/// What VoiceOver and larger text get: which choice is selected, which strip a control belongs to, rows that grow.
@MainActor
final class AccessibilityUITests: DeskUITestCase {
    func testGroupChipsSayWhichIsSelected() {
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
        launch()
        open("Kick")
        app.buttons["edit-strip"].tap()
        let red = app.buttons["color-red"]
        XCTAssertTrue(red.appears(within: 2))
        XCTAssertEqual(red.label, "Red")
        XCTAssertTrue(red.isSelected, "the demo desk colours Kick red")
        XCTAssertFalse(app.buttons["color-green"].isSelected)
        XCTAssertEqual(app.buttons["color-off"].label, "No colour")
    }

    func testDCAMemberRowsGrowWithLargerText() {
        launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        // At this size the chip row runs past the screen's edge, as a thumb would scroll it.
        app.buttons["Inputs"].swipeLeft()
        app.buttons["DCA"].tap()
        open("Drums")
        app.buttons["Members"].tap()
        let snare = element("member-/ch/02")
        XCTAssertTrue(snare.appears(within: 3))
        XCTAssertGreaterThan(snare.frame.height, 44)
    }
}

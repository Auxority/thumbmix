import XCTest

/// The pill bars along the bottom edge: the overview's groups (In, Aux, FX…) and a strip screen's tabs.
@MainActor
final class PillBarUITests: DeskUITestCase {
    /// Every group is one tap, in the same place each time: no swipe first, as the full names on a 375 pt screen
    /// needed for Main and Matrix. The labels stay the full names, so VoiceOver reads "Buses", not "Bus", and says
    /// which is selected. The pills sit along the bottom edge, where a thumb reaches them one-handed.
    func testEveryGroupPillShowsAtOnce() {
        launch()
        let inputs = app.buttons["Inputs"]
        XCTAssertTrue(inputs.appears(within: 5))
        assertEqualPills(["Inputs", "Aux", "FX", "Buses", "DCA", "Main", "Matrix"])
        XCTAssertGreaterThan(inputs.frame.minY, app.frame.height * 0.75, "the pills sit in the bottom quarter")
        XCTAssertTrue(inputs.isSelected, "VoiceOver: Inputs selected")
        saveScreenshot("pills-overview")

        app.buttons["Matrix"].tap()
        XCTAssertTrue(app.buttons["Fill"].appears(within: 2))
        XCTAssertTrue(eventually(within: 2) { self.app.buttons["Matrix"].isSelected }, "VoiceOver: Matrix selected")
        XCTAssertFalse(inputs.isSelected)

        // Switching from far down the inputs to a short group kept the old offset, past that group's end: the list
        // showed only black. Flicked, and the pill tapped while the list still glides, as a thumb does.
        inputs.tap()
        for _ in 0..<3 { app.swipeUp(velocity: .fast) }
        app.buttons["DCA"].tap()
        XCTAssertTrue(app.buttons["Drums"].appears(within: 2))
        XCTAssertTrue(app.buttons["Drums"].isHittable, "the short group shows its list")

        // The list's last strip still scrolls clear of the bar.
        inputs.tap()
        for _ in 0..<6 { app.swipeUp(velocity: .fast) }
        let lastMute = app.buttons["mute-/ch/32/mix/on"]
        XCTAssertTrue(eventually(within: 3) { lastMute.exists && lastMute.frame.maxY <= inputs.frame.minY })
        XCTAssertTrue(lastMute.isHittable)
    }

    /// A strip's tabs are the same native segmented control as the overview's groups (2026-10-29): a tap opens a tab,
    /// and a thumb sliding across them carries iOS's glass lens and opens the tab it's released on.
    func testStripTabsOpenByTapOrSlide() {
        launchAndOpen("Kick")
        assertEqualPills(["Mix", "Input", "Gate", "EQ", "Comp", "Sends"])
        saveScreenshot("pills-channel")
        tabPill("EQ").tap()
        XCTAssertTrue(eventually(within: 2) { self.tabPill("EQ").isSelected }, "a tap opens EQ")
        tabPill("Mix").tap()
        XCTAssertTrue(eventually(within: 2) { self.tabPill("Mix").isSelected })

        tabPill("Mix").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.3, thenDragTo: tabPill("Comp").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssertTrue(eventually(within: 2) { self.tabPill("Comp").isSelected }, "a slide released on Comp opens it")
    }

    /// The lowest button so named: the EQ and Comp tabs have an on/off chip of the same name.
    private func tabPill(_ label: String) -> XCUIElement {
        app.buttons.matching(identifier: label).allElementsBoundByIndex.max { $0.frame.minY < $1.frame.minY }!
    }

    /// All on screen, equally wide and at least 44 pt tall (Apple's smallest touch target): 36 pt pills got missed.
    private func assertEqualPills(_ labels: [String], file: StaticString = #filePath, line: UInt = #line) {
        let frames = labels.map { app.buttons[$0].frame }
        for (label, frame) in zip(labels, frames) {
            XCTAssertTrue(app.buttons[label].isHittable, "\(label) is on screen", file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.height, 44, "\(label) is tall enough", file: file, line: line)
            XCTAssertEqual(frame.width, frames[0].width, accuracy: 1, "\(label) is as wide as the first", file: file, line: line)
        }
    }
}

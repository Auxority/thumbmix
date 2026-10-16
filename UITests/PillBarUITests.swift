import XCTest

/// The pill bars along the bottom edge: the overview's groups (In, Aux, FX…) and a strip screen's tabs.
@MainActor
final class PillBarUITests: DeskUITestCase {
    /// Switching from far down the inputs to a short group kept the old offset, past that group's end:
    /// the list showed only black.
    func testSwitchingToAShortGroupFromFarDownShowsTheList() {
        launch()
        // Flicked, and the pill tapped while the list still glides, as a thumb does.
        for _ in 0..<3 { app.swipeUp(velocity: .fast) }
        app.buttons["DCA"].tap()
        XCTAssertTrue(app.buttons["Drums"].appears(within: 2))
        XCTAssertTrue(app.buttons["Drums"].isHittable)
    }

    func testPillsSwitchGroups() {
        launch()
        app.buttons["Buses"].tap()
        XCTAssertTrue(app.buttons["Mon 1"].appears(within: 2))
    }

    /// Every group is one tap, in the same place each time: no swipe first, as the full names on a 375 pt screen
    /// needed for Main and Matrix. The labels stay the full names, so VoiceOver reads "Buses", not "Bus".
    func testEveryGroupPillShowsAtOnce() {
        launch()
        assertEqualPills(["Inputs", "Aux", "FX", "Buses", "DCA", "Main", "Matrix"])
        saveScreenshot("pills-overview")
        app.buttons["Matrix"].tap()
        XCTAssertTrue(app.buttons["Fill"].appears(within: 2))
    }

    /// A strip's tabs are the same pills as the overview's groups.
    func testStripTabsArePillsLikeTheGroups() {
        launchAndOpen("Kick")
        assertEqualPills(["Mix", "Input", "Gate", "EQ", "Comp", "Sends"])
        saveScreenshot("pills-channel")
    }

    /// A tapped pill is white at once, every time: a Button's action ran animated, so the new pill faded in over
    /// ~0.3 s or not, depending on the tap.
    func testTappedPillTurnsWhiteAtOnce() {
        launchAndOpen("Kick")
        for label in ["EQ", "Comp", "Mix", "Sends"] {
            // The lowest button so named: the EQ and Comp tabs have an on/off chip of the same name.
            let pill = app.buttons.matching(identifier: label).allElementsBoundByIndex.max { $0.frame.minY < $1.frame.minY }!
            pill.tap()
            // Inside the pill's capsule, above its text.
            let inside = CGPoint(x: pill.frame.midX, y: pill.frame.minY + 6)
            XCTAssertGreaterThan(screenBrightness(at: inside), 0.9, "\(label) is white right after the tap")
        }
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

    /// The group pills sit along the bottom edge, where a thumb reaches them one-handed, and the list's last
    /// strip still scrolls clear of the bar.
    func testGroupPillsSitWithinThumbReach() {
        launch()
        let inputs = app.buttons["Inputs"]
        XCTAssertGreaterThan(inputs.frame.minY, app.frame.height * 0.75, "the pills sit in the bottom quarter")
        for _ in 0..<6 { app.swipeUp(velocity: .fast) }
        let lastMute = app.buttons["mute-/ch/32/mix/on"]
        XCTAssertTrue(eventually(within: 3) { lastMute.exists && lastMute.frame.maxY <= inputs.frame.minY })
        XCTAssertTrue(lastMute.isHittable)
    }
}

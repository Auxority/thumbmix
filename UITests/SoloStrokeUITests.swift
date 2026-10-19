import XCTest

/// Hold a name on the overview, then drag up or down the names, as Photos selects (2026-10-19).
final class SoloStrokeUITests: DeskUITestCase {
    private func stroke(from start: String, to end: String) {
        let from = app.buttons[start]
        let to = app.buttons[end]
        XCTAssertTrue(from.isHittable && to.isHittable)
        from.press(forDuration: 0.5, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// A hold solos without opening the strip; a tap still opens it without soloing.
    func testHoldSolosAndTapOpens() {
        launch()
        app.buttons["Kick"].press(forDuration: 0.6)
        XCTAssertTrue(eventually(within: 2) { self.solos(1...1, are: 1) })
        XCTAssertTrue(eventually(within: 2) { (self.app.buttons["Kick"].value as? String) == "1 · Solo" })
        XCTAssertFalse(app.buttons["Mix"].exists, "a hold doesn't open the strip")

        app.buttons["Snare"].tap()
        XCTAssertTrue(app.buttons["Mix"].appears(within: 3))
        XCTAssertTrue(solos(2...2, are: 0))
    }

    func testDraggingSolosARun() {
        launch()
        stroke(from: "Kick", to: "OH R")
        XCTAssertTrue(eventually(within: 2) { self.solos(1...7, are: 1) })
        XCTAssertTrue(solos(8...8, are: 0), "the run stops at the finger")
        saveScreenshot("solo-stroke-run")
    }

    /// The hunt's "keep the half with the noise": a stroke that starts on a soloed name unsolos.
    func testStartingOnASoloedNameUnsolos() {
        for channel in 1...4 { desk.change(soloAddress(channel), 1) }
        launch()
        stroke(from: "Tom 1", to: "Hi-hat")
        XCTAssertTrue(eventually(within: 2) { self.solos(3...4, are: 0) })
        XCTAssertTrue(solos(1...2, are: 1))
    }

    /// A quick flick that starts on a name scrolls the list: only a finger that rests starts soloing.
    func testFlickScrollsAndSolosNothing() {
        launch()
        let kick = app.buttons["Kick"]
        let top = kick.frame.minY
        app.buttons["Snare"].swipeUp()
        XCTAssertTrue(eventually(within: 2) { !kick.exists || kick.frame.minY < top }, "the list scrolled")
        XCTAssertTrue(solos(1...16, are: 0))
    }

    /// Exclusive solo would keep only the last row of a run: the app asks once the finger lifts.
    func testExclusiveAsksBeforeASecondSolo() {
        desk.change(Self.exclusiveSolo, 1)
        launch()
        stroke(from: "Kick", to: "Hi-hat")
        let alert = app.alerts["Exclusive solo is on"]
        XCTAssertTrue(alert.appears(within: 3))
        XCTAssertTrue(solos(1...1, are: 1))
        XCTAssertTrue(solos(2...2, are: 0), "held back while the question is open")
        saveScreenshot("solo-exclusive-alert")

        alert.buttons["Turn off"].tap()

        XCTAssertTrue(eventually(within: 3) { self.solos(1...3, are: 1) })
        XCTAssertEqual(desk.value(Self.exclusiveSolo), .int(0))
    }

    func testKeepLeavesOneSoloAndAsksNoMore() {
        desk.change(Self.exclusiveSolo, 1)
        launch()
        stroke(from: "Kick", to: "Hi-hat")
        app.alerts["Exclusive solo is on"].buttons["Keep"].tap()
        XCTAssertTrue(eventually(within: 2) { (self.app.buttons["Hi-hat"].value as? String) == "3" })
        XCTAssertTrue(solos(2...2, are: 0))

        stroke(from: "Tom 1", to: "Tom 2")

        // Kept: the desk keeps one solo at a time, so the run ends on its last row.
        XCTAssertTrue(eventually(within: 3) { self.solos(5...5, are: 1) })
        XCTAssertFalse(app.alerts.firstMatch.exists, "asked once per desk")
        XCTAssertEqual(desk.value(Self.exclusiveSolo), .int(1))
    }

    /// The stroke counts only over the names: a finger that drifts onto the faders leaves them and the mutes alone.
    func testStrokeLeavesFadersAndMutesAlone() {
        launch()
        let fader = desk.value("/ch/03/mix/fader")
        let kick = app.buttons["Kick"]
        let overFader = app.buttons["Hi-hat"].coordinate(withNormalizedOffset: CGVector(dx: 2.5, dy: 0.5))
        kick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: overFader, withVelocity: .slow, thenHoldForDuration: 0.2)
        XCTAssertTrue(eventually(within: 2) { self.solos(1...3, are: 1) })
        XCTAssertEqual(desk.value("/ch/03/mix/fader"), fader)
        XCTAssertEqual(desk.value("/ch/03/mix/on"), .int(1), "not muted")
    }
}

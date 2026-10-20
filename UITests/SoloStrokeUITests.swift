import XCTest

/// Hold a name on the overview, then drag up or down the names, as Photos selects (2026-10-19). Holding one name and
/// tapping to open are in `SoloUITests`.
final class SoloStrokeUITests: DeskUITestCase {
    private func stroke(from start: String, to end: String) {
        let from = app.buttons[start]
        let to = app.buttons[end]
        XCTAssertTrue(from.isHittable && to.isHittable)
        from.press(forDuration: 0.5, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// The stroke counts only over the names: a finger that drifts onto the faders leaves them and the mutes alone.
    /// A run stops at the finger. The hunt's "keep the half with the noise": a stroke that starts on a soloed name
    /// unsolos. A quick flick that starts on a name scrolls the list: only a finger that rests starts soloing.
    func testDraggingSolosARun() {
        launch()
        let fader = desk.value("/ch/03/mix/fader")
        let overFader = app.buttons["Hi-hat"].coordinate(withNormalizedOffset: CGVector(dx: 2.5, dy: 0.5))
        app.buttons["Kick"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: overFader, withVelocity: .slow, thenHoldForDuration: 0.2)
        XCTAssertTrue(eventually(within: 2) { self.solos(1...3, are: 1) }, "Kick to Hi-hat")
        XCTAssertEqual(desk.value("/ch/03/mix/fader"), fader, "the fader under the finger stayed")
        XCTAssertEqual(desk.value("/ch/03/mix/on"), .int(1), "not muted")

        stroke(from: "Tom 1", to: "OH R")
        XCTAssertTrue(eventually(within: 2) { self.solos(4...7, are: 1) }, "Tom 1 to OH R")
        XCTAssertTrue(solos(8...8, are: 0), "the run stops at the finger")
        saveScreenshot("solo-stroke-run")

        stroke(from: "Tom 1", to: "Hi-hat")
        XCTAssertTrue(eventually(within: 2) { self.solos(3...4, are: 0) }, "a stroke from a soloed name unsolos")
        XCTAssertTrue(solos(1...2, are: 1))
        XCTAssertTrue(solos(5...7, are: 1))

        let kick = app.buttons["Kick"]
        let top = kick.frame.minY
        app.buttons["Snare"].swipeUp()
        XCTAssertTrue(eventually(within: 2) { !kick.exists || kick.frame.minY < top }, "the list scrolled")
        XCTAssertTrue(solos(3...4, are: 0), "the flick soloed nothing")
        XCTAssertTrue(solos(8...16, are: 0), "the flick soloed nothing")
    }

    /// Exclusive solo would keep only the last row of a run: the app asks once the finger lifts. Keep is a Core test
    /// (`SoloStrokeMirrorTests.keepLeavesOneSoloAndAsksNoMore`).
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
}

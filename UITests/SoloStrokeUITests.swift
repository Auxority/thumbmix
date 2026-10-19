import XCTest

/// Hold a name on the overview, then drag up or down the names, as Photos selects (2026-10-19).
final class SoloStrokeUITests: DeskUITestCase {
    private func solo(_ channel: Int) -> String { String(format: "/-stat/solosw/%02d", channel) }

    private func soloed(_ channels: ClosedRange<Int>) -> Bool {
        channels.allSatisfy { desk.value(solo($0)) == .int(1) }
    }

    private func unsoloed(_ channels: ClosedRange<Int>) -> Bool {
        channels.allSatisfy { desk.value(solo($0)) == .int(0) }
    }

    private func stroke(from start: String, to end: String) {
        let from = app.buttons[start]
        let to = app.buttons[end]
        XCTAssertTrue(from.isHittable && to.isHittable)
        from.press(forDuration: 0.5, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    func testHoldingANameSolosIt() {
        launch()
        app.buttons["Kick"].press(forDuration: 0.6)
        XCTAssertTrue(eventually(within: 2) { self.soloed(1...1) })
        XCTAssertTrue(eventually(within: 2) { (self.app.buttons["Kick"].value as? String) == "1 · Solo" })
        XCTAssertFalse(app.buttons["Mix"].exists, "a hold doesn't open the strip")
    }

    func testDraggingSolosARun() {
        launch()
        stroke(from: "Kick", to: "OH R")
        XCTAssertTrue(eventually(within: 2) { self.soloed(1...7) })
        XCTAssertEqual(desk.value(solo(8)), .int(0), "the run stops at the finger")
        saveScreenshot("solo-stroke-run")
    }

    /// The hunt's "keep the half with the noise": a stroke that starts on a soloed name unsolos.
    func testStartingOnASoloedNameUnsolos() {
        for channel in 1...4 { desk.change(solo(channel), 1) }
        launch()
        stroke(from: "Tom 1", to: "Hi-hat")
        XCTAssertTrue(eventually(within: 2) { self.unsoloed(3...4) })
        XCTAssertTrue(soloed(1...2))
    }

    func testTapStillOpensTheStrip() {
        launch()
        app.buttons["Kick"].tap()
        XCTAssertTrue(app.buttons["Mix"].appears(within: 3))
        XCTAssertEqual(desk.value(solo(1)), .int(0))
    }

    /// A quick flick that starts on a name scrolls the list: only a finger that rests starts soloing.
    func testFlickScrollsAndSolosNothing() {
        launch()
        let kick = app.buttons["Kick"]
        let top = kick.frame.minY
        app.buttons["Snare"].swipeUp()
        XCTAssertTrue(eventually(within: 2) { !kick.exists || kick.frame.minY < top }, "the list scrolled")
        XCTAssertTrue(unsoloed(1...16))
    }

    /// The stroke counts only over the names: a finger that drifts onto the faders leaves them and the mutes alone.
    func testStrokeLeavesFadersAndMutesAlone() {
        launch()
        let fader = desk.value("/ch/03/mix/fader")
        let kick = app.buttons["Kick"]
        let overFader = app.buttons["Hi-hat"].coordinate(withNormalizedOffset: CGVector(dx: 2.5, dy: 0.5))
        kick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: overFader, withVelocity: .slow, thenHoldForDuration: 0.2)
        XCTAssertTrue(eventually(within: 2) { self.soloed(1...3) })
        XCTAssertEqual(desk.value("/ch/03/mix/fader"), fader)
        XCTAssertEqual(desk.value("/ch/03/mix/on"), .int(1), "not muted")
    }
}

import XCTest

/// The EQ tab, walked on Kick: the live spectrum, the graph, the low cut, the desk switching the EQ off, a band's type,
/// Reset bands, and the spectrum after the background.
@MainActor
final class EQUITests: DeskUITestCase {
    /// Where band 1 of an input sits on the graph at its default: 91.4 Hz on the log axis, 0 dB.
    private static let kickBand1 = CGVector(dx: log(91.4 / 20) / log(1000), dy: 0.5)

    func testTheEQTab() {
        launchAndOpen("Kick", tab: "EQ")
        nothingMovesWhenTheSpectrumArrives()
        let frequency = element("/ch/01/eq/1/f")
        XCTAssertTrue(frequency.appears(within: 5))
        let graph = element("eq-graph")
        dragOnTheGraphMovesTheGrabbedBand(graph)
        lowCutIsTheFirstChoiceInTheBandPicker(graph)
        theDesksEQOffKeepsTheCurve(graph)
        app.buttons["1"].tap()
        bandTypeIsADropdown(graph)
        resetBandsAsksFirst(frequency)
        theSpectrumComesBackAfterTheBackground()
    }

    /// The EQ tab borrows the desk's RTA for this channel; the status line shows once spectrum data arrives. It used to
    /// appear only then, pushing everything under it down a line: Reset bands showed for a moment, then jumped.
    private func nothingMovesWhenTheSpectrumArrives() {
        let reset = app.buttons["Reset bands"]
        XCTAssertTrue(reset.appears(within: 2))
        let before = reset.frame.minY
        XCTAssertTrue(eventually(within: 5) { self.rtaFollowsKick }, "the spectrum arrived")
        saveScreenshot("eq-spectrum")
        XCTAssertEqual(reset.frame.minY, before, accuracy: 0.5, "Reset bands stayed put")
    }

    /// Coming back from another app rebuilds the link; the RTA must be borrowed again once it is live.
    private func theSpectrumComesBackAfterTheBackground() {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(eventually(within: 5) { [.runningBackground, .runningBackgroundSuspended].contains(self.app.state) })
        app.activate()
        XCTAssertTrue(eventually(within: 10) { self.rtaFollowsKick }, "the spectrum came back")
    }

    private var rtaFollowsKick: Bool {
        let status = app.staticTexts["rta-status"]
        return status.exists && status.label == "RTA follows Kick (after EQ)"
    }

    /// A touch near a band point grabs it, but only movement moves it: landing slightly off the point must not jump
    /// the desk to where the finger happens to be. A drag moves the band; a double-tap on it resets it at once.
    private func dragOnTheGraphMovesTheGrabbedBand(_ graph: XCUIElement) {
        let frequency = element("/ch/01/eq/1/f")
        let gain = element("/ch/01/eq/1/g")
        XCTAssertEqual(frequency.value as? String, "91.4 Hz")
        let nearBand1 = graph.coordinate(withNormalizedOffset: Self.kickBand1).withOffset(CGVector(dx: 20, dy: -25))
        nearBand1.press(forDuration: 0.3)
        XCTAssertEqual(frequency.value as? String, "91.4 Hz", "a touch near the band moved it")
        XCTAssertEqual(gain.value as? String, "0.0 dB", "a touch near the band moved it")

        let deskBefore = desk.value("/ch/01/eq/1/f")
        let moved = CGVector(dx: 0.5, dy: 0.25)
        graph.coordinate(withNormalizedOffset: Self.kickBand1)
            .press(forDuration: 0.1, thenDragTo: graph.coordinate(withNormalizedOffset: moved))
        XCTAssertNotEqual(frequency.value as? String, "91.4 Hz")
        XCTAssertNotEqual(gain.value as? String, "0.0 dB")
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/eq/1/f") != deskBefore }, "the drag reached the desk")
        saveScreenshot("task-15-eq")
        graph.coordinate(withNormalizedOffset: moved).doubleTap()
        XCTAssertTrue(eventually(within: 2) { gain.value as? String == "0.0 dB" }, "a double-tap resets the band")
    }

    /// Off, the cut as set is drawn dashed, like unheard bands (2026-10-17).
    private func lowCutIsTheFirstChoiceInTheBandPicker(_ graph: XCUIElement) {
        app.buttons["LC"].tap()
        let on = element("toggle-/ch/01/preamp/hpon")
        XCTAssertTrue(on.appears(within: 2))
        XCTAssertEqual(on.value as? String, "Off")
        XCTAssertEqual(element("/ch/01/preamp/hpf").value as? String, "89.4 Hz")
        let slope = app.buttons["/ch/01/preamp/hpslope"]
        XCTAssertEqual(slope.value as? String, "24 dB/oct")
        slope.tap()
        app.buttons["12 dB/oct"].tap()
        XCTAssertEqual(slope.value as? String, "12 dB/oct")
        XCTAssertTrue((graph.value as? String)?.contains("Low cut off") == true)
        saveScreenshot("low-cut-off")
        on.tap()
        XCTAssertEqual(on.value as? String, "On")
        XCTAssertTrue(eventually(within: 2) { (graph.value as? String)?.contains("Low cut off") == false })
        saveScreenshot("low-cut")
    }

    /// The desk switches the EQ off: the graph keeps the bands as set, drawn dashed (mock C), and says so.
    private func theDesksEQOffKeepsTheCurve(_ graph: XCUIElement) {
        desk.change("/ch/01/eq/2/g", float: 0.3)
        desk.change("/ch/01/eq/on", 0)
        XCTAssertTrue(eventually(within: 2) { graph.value as? String == "EQ off" }, "the desk's EQ off reached the graph")
        saveScreenshot("eq-off-dashed")
        desk.change("/ch/01/eq/on", 1)
        XCTAssertTrue(eventually(within: 2) { graph.value as? String != "EQ off" }, "and back on")
    }

    /// Type is a list: it says each type in words, the desk's term under it, and the closed row keeps the desk's term.
    /// A cut filter has no level to shape: its Gain and Q rows stay in place but take no edits. The tab scrolls as a
    /// whole, graph included.
    private func bandTypeIsADropdown(_ graph: XCUIElement) {
        let type = app.buttons["/ch/01/eq/1/type"]
        let gain = element("/ch/01/eq/1/g")
        let q = element("/ch/01/eq/1/q")
        XCTAssertTrue(type.appears(within: 2))
        XCTAssertEqual(type.value as? String, "PEQ")
        type.tap()
        let lowShelf = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Low shelf")).firstMatch
        XCTAssertTrue(lowShelf.appears(within: 2))
        saveScreenshot("eq-type-list")
        lowShelf.tap()
        XCTAssertEqual(type.value as? String, "LShv")
        XCTAssertTrue(gain.isEnabled)

        type.tap()
        // Not the "Low cut" chip behind the menu: the list's item carries the desk's term too.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Low cut' AND label CONTAINS 'LCut'")).firstMatch.tap()
        XCTAssertTrue(eventually(within: 2) { !gain.isEnabled && !q.isEnabled }, "a cut filter takes no Gain or Q")
        XCTAssertEqual(gain.value as? String, "—", "a number would suggest the row still does something")
        XCTAssertEqual(q.value as? String, "—")
        let before = gain.frame
        gain.doubleTap()
        XCTAssertEqual(app.alerts.count, 0, "a disabled row doesn't offer a reset")
        XCTAssertEqual(gain.frame, before, "the rows stay where they were")
        saveScreenshot("eq-cut-band")

        let top = graph.frame.minY
        // Drag from the Type row: on a 375 pt phone the rows below it start at the screen's bottom edge.
        let start = type.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -250)))
        XCTAssertLessThan(graph.frame.minY, top, "the tab scrolls as a whole")
        saveScreenshot("eq-scrolled")
    }

    /// The system alert, like every other "are you sure" in the app.
    private func resetBandsAsksFirst(_ frequency: XCUIElement) {
        frequency.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: frequency.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
        let moved = frequency.value as? String
        XCTAssertNotEqual(moved, "91.4 Hz")
        let reset = app.buttons["Reset bands"]
        if !reset.isHittable {
            let type = app.buttons["/ch/01/eq/1/type"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            type.press(forDuration: 0.05, thenDragTo: type.withOffset(CGVector(dx: 0, dy: -300)))
        }
        reset.tap()
        let alert = app.alerts["Reset all 4 bands of Kick?"]
        XCTAssertTrue(alert.appears(within: 2))
        alert.buttons["Cancel"].tap()
        XCTAssertEqual(frequency.value as? String, moved, "Cancel leaves the bands")
        reset.tap()
        alert.buttons["Reset"].tap()
        XCTAssertEqual(frequency.value as? String, "91.4 Hz")
    }
}

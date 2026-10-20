import ThumbmixCore
import XCTest

/// The key graph in the Comp and Gate sheets (2026-10-20): the key filter over the RTA of what the key listens to,
/// with the live gain reduction along its bottom edge.
@MainActor
final class KeyGraphUITests: DeskUITestCase {
    func testTheGateKeyGraphFollowsItsSourceBeforeTheEQ() {
        desk.change("/ch/01/gate/keysrc", 2)
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        XCTAssertTrue(element("key-graph").appears(within: 2))
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(3), .int(0)) }, "Snare, before its EQ")
        saveScreenshot("key-graph-gate")
    }

    func testTheCaptionSaysBeforeEQ() {
        desk.change("/ch/01/gate/keysrc", 2)
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        let caption = element("rta-status")
        XCTAssertTrue(eventually(within: 3) { caption.label == "RTA follows Snare (before EQ)" }, caption.label)
    }

    func testSelfOnTheCompFollowsCompPosition() {
        desk.change("/ch/01/dyn/keysrc", 0)
        desk.change("/ch/01/dyn/pos", 1)
        launchAndOpen("Kick", tab: "Comp")
        openSheet("comp-more", title: "Comp · Kick")
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(2), .int(1)) }, "Kick, after its EQ")
        let caption = element("rta-status")
        XCTAssertTrue(eventually(within: 3) { caption.label == "RTA follows Kick (after EQ)" }, caption.label)
        saveScreenshot("key-graph-comp")
    }

    func testChangingTheSourceRepointsTheRTA() {
        desk.change("/ch/01/dyn/keysrc", 0)
        desk.change("/ch/01/dyn/pos", 1)
        launchAndOpen("Kick", tab: "Comp")
        openSheet("comp-more", title: "Comp · Kick")
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(2), .int(1)) })
        let source = app.buttons["/ch/01/dyn/keysrc"]
        source.tap()
        let snare = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ch 2 · Snare")).firstMatch
        XCTAssertTrue(snare.appears(within: 2))
        snare.tap()
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(3), .int(0)) }, "Snare, before its EQ")
    }

    func testClosingTheSheetHandsTheRTABack() {
        desk.change(RTA.source, 50)
        desk.change(RTA.position, 1)
        desk.change("/ch/01/gate/keysrc", 2)
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(3), .int(0)) })
        app.buttons["Done"].tap()
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(50), .int(1)) }, "the desk's own setting")
    }

    /// Sideways anywhere on the graph, like a row: the one point needn't be hit.
    func testDraggingTheGraphMovesTheFilterFrequency() {
        desk.change("/ch/01/gate/filter/on", 1)
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        let graph = element("key-graph")
        XCTAssertTrue(graph.appears(within: 2))
        let start = frequency()
        graph.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: graph.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
        XCTAssertTrue(eventually(within: 2) { self.frequency() > start + 0.1 }, "Freq moved up")
        saveScreenshot("key-graph-filter-on")
    }

    /// Like a row: only a sideways drag moves Freq, so a swipe down to close the sheet never nudges it.
    func testAVerticalSwipeOnTheGraphLeavesFreq() {
        desk.change("/ch/01/gate/filter/on", 1)
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        let graph = element("key-graph")
        XCTAssertTrue(graph.appears(within: 2))
        let start = frequency()
        graph.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(forDuration: 0.05, thenDragTo: graph.coordinate(withNormalizedOffset: CGVector(dx: 0.56, dy: 0.95)))
        XCTAssertFalse(eventually(within: 1) { self.frequency() != start }, "Freq moved")
    }

    /// Once the drag ends, the desk's own changes show again: the edit hold doesn't outlive the finger.
    func testTheDesksFrequencyShowsAgainAfterADrag() {
        desk.change("/ch/01/gate/filter/on", 1)
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        let graph = element("key-graph")
        XCTAssertTrue(graph.appears(within: 2))
        graph.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: graph.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        let row = element("/ch/01/gate/filter/f")
        let dragged = row.value as? String
        Thread.sleep(forTimeInterval: 1)
        desk.change("/ch/01/gate/filter/f", float: 0.1)
        XCTAssertTrue(eventually(within: 3) { row.value as? String != dragged }, "the desk's value")
    }

    func testTheGraphReadsItsFilterToVoiceOver() {
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        let graph = element("key-graph")
        XCTAssertTrue(graph.appears(within: 2))
        XCTAssertEqual(graph.label, "Key filter")
        XCTAssertEqual(graph.value as? String, "HC12 632 Hz, Off")
    }

    /// The engineer points the RTA elsewhere on the desk while the sheet is open: the desk wins, and the line says so.
    func testTheDeskTakingTheRTABackSaysSo() {
        desk.change("/ch/01/gate/keysrc", 2)
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(3), .int(0)) })
        Thread.sleep(forTimeInterval: 0.5)
        desk.change(RTA.source, 66)
        let caption = element("rta-status")
        XCTAssertTrue(eventually(within: 3) { caption.label == "RTA: in use on the desk" }, caption.label)
        app.buttons["Done"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(desk.value(RTA.source), .int(66), "the engineer's choice stays")
    }

    /// A gate's cut is gain reduction too (doc p.17): the graph shows when the key makes it act.
    func testTheGraphShowsGainReduction() {
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        let reduction = element("key-reduction")
        XCTAssertTrue(reduction.appears(within: 2))
        XCTAssertTrue(reduction.label.hasPrefix("GR "), reduction.label)
    }

    private var rta: (OSCArgument?, OSCArgument?) { (desk.value(RTA.source), desk.value(RTA.position)) }

    private func frequency() -> Float {
        if case .float(let value)? = desk.value("/ch/01/gate/filter/f") { return value }
        return -1
    }

    private func openSheet(_ line: String, title: String) {
        let button = app.buttons[line]
        XCTAssertTrue(button.appears(within: 2), line)
        button.tap()
        XCTAssertTrue(app.navigationBars[title].appears(within: 2), title)
    }
}

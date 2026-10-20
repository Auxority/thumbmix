import ThumbmixCore
import XCTest

/// The key graph in the Comp and Gate sheets (2026-10-20): the key filter over the RTA of what the key listens to,
/// with the live gain reduction along its bottom edge.
@MainActor
final class KeyGraphUITests: DeskUITestCase {
    /// The gate keyed on Snare: the sheet borrows the RTA for what the key hears, says so, and hands it back on Done.
    /// Reopened, the engineer pointing the RTA elsewhere on the desk wins, and the caption says so.
    func testTheGateKeySheetBorrowsTheRTAAndHandsItBack() {
        desk.change(RTA.source, 50)
        desk.change(RTA.position, 1)
        desk.change("/ch/01/gate/keysrc", 2)
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        let graph = element("key-graph")
        XCTAssertTrue(graph.appears(within: 2))
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(3), .int(0)) }, "borrowed: Snare, before its EQ")
        let caption = element("rta-status")
        XCTAssertTrue(eventually(within: 3) { caption.label == "RTA follows Snare (before EQ)" }, caption.label)
        // A gate's cut is gain reduction too (doc p.17): the graph shows when the key makes it act.
        XCTAssertTrue(element("key-reduction").label.hasPrefix("GR "), "gain reduction")
        XCTAssertEqual(graph.label, "Key filter", "VoiceOver")
        XCTAssertEqual(graph.value as? String, "HC12 632 Hz, Off", "VoiceOver")
        saveScreenshot("key-graph-gate")

        app.buttons["Done"].tap()
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(50), .int(1)) }, "handed back: the desk's own setting")

        openSheet("gate-key", title: "Gate key · Kick")
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(3), .int(0)) }, "borrowed again")
        Thread.sleep(forTimeInterval: 0.5)
        desk.change(RTA.source, 66)
        XCTAssertTrue(eventually(within: 3) { caption.label == "RTA: in use on the desk" }, caption.label)
        app.buttons["Done"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(desk.value(RTA.source), .int(66), "the engineer's choice stays")
    }

    /// The comp keyed on itself follows its position (after the EQ here); picking another source repoints the RTA.
    func testChangingTheSourceRepointsTheRTA() {
        desk.change("/ch/01/dyn/keysrc", 0)
        desk.change("/ch/01/dyn/pos", 1)
        launchAndOpen("Kick", tab: "Comp")
        openSheet("comp-more", title: "Comp · Kick")
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(2), .int(1)) }, "Self: Kick, after its EQ")
        let caption = element("rta-status")
        XCTAssertTrue(eventually(within: 3) { caption.label == "RTA follows Kick (after EQ)" }, caption.label)
        saveScreenshot("key-graph-comp")

        app.buttons["/ch/01/dyn/keysrc"].tap()
        let snare = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ch 2 · Snare")).firstMatch
        XCTAssertTrue(snare.appears(within: 2))
        snare.tap()
        XCTAssertTrue(eventually(within: 3) { self.rta == (.int(3), .int(0)) }, "Snare, before its EQ")
    }

    /// Like a row: only a sideways drag moves Freq, anywhere on the graph (so a swipe down to close the sheet never
    /// nudges it), and once the drag ends the desk's own changes show again: the edit hold doesn't outlive the finger.
    func testDraggingTheGraphMovesTheFilterFrequency() {
        desk.change("/ch/01/gate/filter/on", 1)
        launchAndOpen("Kick", tab: "Gate")
        openSheet("gate-key", title: "Gate key · Kick")
        let graph = element("key-graph")
        XCTAssertTrue(graph.appears(within: 2))
        let start = frequency()
        graph.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: graph.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
        XCTAssertTrue(eventually(within: 2) { self.frequency() > start + 0.1 }, "a sideways drag moves Freq up")
        saveScreenshot("key-graph-filter-on")

        let row = element("/ch/01/gate/filter/f")
        let dragged = row.value as? String
        Thread.sleep(forTimeInterval: 1)
        desk.change("/ch/01/gate/filter/f", float: 0.1)
        XCTAssertTrue(eventually(within: 3) { row.value as? String != dragged }, "the desk's value shows after the drag")

        // Last: the swipe down may close the sheet.
        graph.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(forDuration: 0.05, thenDragTo: graph.coordinate(withNormalizedOffset: CGVector(dx: 0.56, dy: 0.95)))
        XCTAssertFalse(eventually(within: 1) { self.frequency() != 0.1 }, "a vertical swipe moved Freq")
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

import XCTest

/// A row's double-tap reset.
@MainActor
final class EQBandUITests: DeskUITestCase {
    /// Like a double-tap on the band's point in the graph, every row resets at once, no question: an EQ band's
    /// frequency, and on the Input tab the delay and the preamp gain.
    func testDoubleTappingARowRestoresTheDefaultAtOnce() {
        launchAndOpen("Kick", tab: "EQ")
        let frequency = element("/ch/01/eq/1/f")
        XCTAssertTrue(frequency.appears(within: 2))
        dragAndDoubleTap(frequency, from: "124.7 Hz")

        app.buttons["Input"].tap()
        let time = element("/ch/01/delay/time")
        XCTAssertTrue(time.appears(within: 2))
        dragAndDoubleTap(time, from: "0.30 ms · 0.3 ft")

        let gain = element("/headamp/032/gain")
        XCTAssertEqual(gain.value as? String, "+24.0 dB")
        gain.doubleTap()
        XCTAssertTrue(eventually(within: 2) { gain.value as? String == "0.0 dB" }, "the preamp gain reset")
        XCTAssertEqual(app.alerts.count, 0)

        // The demo's comps start at 12 dB makeup and 2:1; their resets are 0 dB and 3:1.
        app.buttons["Comp"].tap()
        let makeup = element("/ch/01/dyn/mgain")
        XCTAssertTrue(makeup.appears(within: 2))
        XCTAssertEqual(makeup.value as? String, "12.0 dB")
        makeup.doubleTap()
        XCTAssertTrue(eventually(within: 2) { makeup.value as? String == "0.0 dB" }, "the makeup gain reset")
        let ratio = element("/ch/01/dyn/ratio")
        XCTAssertEqual(ratio.value as? String, "2.0:1")
        ratio.doubleTap()
        XCTAssertTrue(eventually(within: 2) { ratio.value as? String == "3.0:1" }, "the ratio reset")
        XCTAssertEqual(app.alerts.count, 0)
    }

    private func dragAndDoubleTap(_ row: XCUIElement, from initial: String) {
        XCTAssertEqual(row.value as? String, initial)
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
        XCTAssertNotEqual(row.value as? String, initial, "the drag moved it")
        row.doubleTap()
        XCTAssertTrue(eventually(within: 2) { row.value as? String == initial }, "the double-tap reset it")
        XCTAssertEqual(app.alerts.count, 0)
    }
}

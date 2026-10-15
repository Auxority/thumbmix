import ThumbmixCore
import XCTest

/// The Mix tab's Insert block (mock A′, 2026-10-14): slot read-only, Insert asks first only for an aux slot.
@MainActor
final class InsertUITests: DeskUITestCase {
    func testAnFXInsertSwitchesOnAtOnce() {
        desk.change("/ch/13/insert/on", 0)
        launch()
        open("Vox 1")
        let slot = element("/ch/13/insert/sel")
        let insert = app.buttons["toggle-/ch/13/insert/on"]
        XCTAssertTrue(slot.appears(within: 2))
        XCTAssertEqual(slot.value as? String, "FX5 L · Dual DeEsser")
        XCTAssertTrue(insert.isHittable, "on the SE's first screen")
        insert.tap()
        XCTAssertTrue(eventually(within: 2) { insert.value as? String == "On" })
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/insert/on") == .int(1) })
        saveScreenshot("insert-fx")
    }

    func testAnAuxInsertAsksFirst() {
        launch()
        open("Bass")
        let insert = app.buttons["toggle-/ch/08/insert/on"]
        XCTAssertTrue(insert.appears(within: 2))
        insert.tap()
        let alert = app.alerts["Turn on the insert for Bass?"]
        XCTAssertTrue(alert.appears(within: 2))
        saveScreenshot("insert-aux-alert")
        alert.buttons["Cancel"].tap()
        XCTAssertEqual(insert.value as? String, "Off")
        XCTAssertEqual(desk.value("/ch/08/insert/on"), .int(0))

        // An alert ignores a reopen while it still animates out.
        XCTAssertTrue(eventually(within: 2) { !alert.exists })
        insert.tap()
        XCTAssertTrue(alert.appears(within: 2))
        alert.buttons["Turn On"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/08/insert/on") == .int(1) })
    }

    func testNoSlotDisablesTheInsert() {
        launch()
        open("Kick")
        let slot = element("/ch/01/insert/sel")
        XCTAssertTrue(slot.appears(within: 2))
        XCTAssertEqual(slot.value as? String, "None")
        XCTAssertFalse(app.buttons["toggle-/ch/01/insert/on"].isEnabled)
        XCTAssertFalse(element("/ch/01/insert/pos").isEnabled)
    }

    func testPositionPicksBeforeTheEQ() {
        launch()
        open("Vox 1")
        let position = app.buttons["/ch/13/insert/pos"]
        XCTAssertTrue(position.appears(within: 2))
        position.tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Before EQ")).firstMatch
        XCTAssertTrue(option.appears(within: 2))
        option.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/insert/pos") == .int(0) })
    }

    /// The Mix tab scrolls to fit the Insert blocks, but a fader drag that wanders vertically must stay a drag.
    func testASlantedFaderDragOnAPairDoesNotScrollThePage() {
        launch()
        app.swipeUp()
        app.buttons["Gtr"].tap()
        XCTAssertTrue(app.buttons["+1 dB"].appears(within: 3))
        let fader = element("/ch/09/mix/fader")
        XCTAssertTrue(fader.appears(within: 2))
        let before = fader.value as? String
        let top = fader.frame.minY
        fader.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3))
            .press(forDuration: 0.05, thenDragTo: fader.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.9)))
        XCTAssertTrue(eventually(within: 2) { fader.value as? String != before })
        XCTAssertEqual(fader.frame.minY, top, accuracy: 2, "the page scrolled")
    }
}

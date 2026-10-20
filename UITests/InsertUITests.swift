import ThumbmixCore
import XCTest

/// The Mix tab's Insert block (mock A′, 2026-10-14): slot read-only, Insert asks first only for an aux slot.
@MainActor
final class InsertUITests: DeskUITestCase {
    /// I1 (2026-10-20): one line under Pan, like the Comp's, that opens today's block in a sheet. An FX slot switches
    /// on at once (no question), and Position picks where it sits.
    func testAnFXInsertSwitchesOnAtOnce() {
        desk.change("/ch/13/insert/on", 0)
        launchAndOpen("Vox 1")
        let line = element("insert-more")
        XCTAssertTrue(line.appears(within: 2))
        XCTAssertTrue(line.isHittable, "on the SE's first screen")
        XCTAssertTrue(eventually(within: 2) { (line.value as? String)?.hasSuffix("· Off") == true })
        XCTAssertEqual(line.value as? String, "FX5 L · Dual DeEsser · Off")
        openInsert(title: "Insert · Vox 1")
        saveScreenshot("insert-sheet")
        let slot = element("/ch/13/insert/sel")
        let insert = app.buttons["toggle-/ch/13/insert/on"]
        XCTAssertTrue(slot.appears(within: 2))
        XCTAssertEqual(slot.value as? String, "FX5 L · Dual DeEsser")
        insert.tap()
        XCTAssertTrue(eventually(within: 2) { insert.value as? String == "On" })
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/insert/on") == .int(1) })
        saveScreenshot("insert-fx")

        let position = app.buttons["/ch/13/insert/pos"]
        position.tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Before EQ")).firstMatch
        XCTAssertTrue(option.appears(within: 2))
        option.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/insert/pos") == .int(0) }, "Before EQ")

        app.buttons["Done"].tap()
        XCTAssertTrue(eventually(within: 2) { (self.element("insert-more").value as? String)?.hasSuffix("· On") == true })
        saveScreenshot("insert-line-on")

        // The engineer clears the slot on the desk: the line says so, and the sheet has nothing left to switch.
        desk.change("/ch/13/insert/sel", 0)
        XCTAssertTrue(eventually(within: 2) { line.value as? String == "No slot picked on the desk" })
        openInsert(title: "Insert · Vox 1")
        XCTAssertTrue(eventually(within: 2) { slot.value as? String == "None" })
        XCTAssertFalse(insert.isEnabled, "no slot, no insert to switch")
        XCTAssertFalse(element("/ch/13/insert/pos").isEnabled, "no slot, no position")
    }

    func testAnAuxInsertAsksFirst() {
        launchAndOpen("Bass")
        openInsert(title: "Insert · Bass")
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

    private func openInsert(title: String) {
        let line = app.buttons["insert-more"]
        XCTAssertTrue(line.appears(within: 2))
        line.tap()
        XCTAssertTrue(app.navigationBars[title].appears(within: 2), title)
    }
}

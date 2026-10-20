import XCTest

/// The "to Main LR" pill on the Mix tab's name line (mock 2026-10-13): every tap asks first, both ways.
@MainActor
final class MainLRUITests: DeskUITestCase {
    /// The pill is on the Mix tab only. It is taller than the name: without a fixed header height the fader sat 4 pt
    /// lower on Mix than on EQ. A matrix has none (`SendsUITests`).
    func testTakingAChannelOutAndBackAsksEachTime() {
        launchAndOpen("Kick")
        let pill = element("mainLR-/ch/01/mix/st")
        XCTAssertTrue(pill.appears(within: 2))
        XCTAssertEqual(pill.label, "Kick in the main mix")

        pill.tap()
        let takeOut = app.alerts["Take Kick out of the main mix?"]
        XCTAssertTrue(takeOut.appears(within: 2))
        saveScreenshot("main-lr-alert")
        takeOut.buttons["Take out"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/mix/st") == .int(0) })
        XCTAssertTrue(eventually(within: 2) { pill.label == "Kick out of the main mix" })
        saveScreenshot("main-lr-out")

        Thread.sleep(forTimeInterval: 0.4)
        pill.tap()
        let sendBack = app.alerts["Send Kick to the main mix?"]
        XCTAssertTrue(sendBack.appears(within: 2))
        sendBack.buttons["Cancel"].tap()
        XCTAssertEqual(desk.value("/ch/01/mix/st"), .int(0), "Cancel changes nothing")

        let onMix = element("/ch/01/mix/fader").frame.minY
        app.buttons["EQ"].tap()
        XCTAssertTrue(eventually(within: 2) { !pill.exists }, "not on other tabs")
        XCTAssertEqual(element("/ch/01/mix/fader").frame.minY, onMix, accuracy: 0.5, "the fader didn't move")
    }
}

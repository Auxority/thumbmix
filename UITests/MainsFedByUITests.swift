import XCTest

/// The mains' Fed by (mocks A, F1 and F4, 2026-10-13): Main LR's rows are each strip's LR switch and own fader, captioned
/// "Fader" under a note saying so; Main M's are the mono send, On and level, like a bus's.
@MainActor
final class MainsFedByUITests: DeskUITestCase {
    /// The LR chip asks first, like the Mix tab's pill: a stray tap while scrolling can drop a vocal from the PA.
    func testMainLRRowsAreTheLRSwitchAndTheStripsFader() {
        launch()
        openMain("LR")
        let kickFader = element("/ch/01/mix/fader")
        XCTAssertTrue(kickFader.appears(within: 2))
        XCTAssertEqual(kickFader.label, "Kick, Ch 1 · Fader")
        XCTAssertEqual(kickFader.value as? String, "0.0 dB")
        let chip = element("mainLR-/ch/01/mix/st")
        XCTAssertEqual(chip.label, "Kick in the main mix")
        XCTAssertTrue(element("fader-note").exists, "said once more above the list (F4)")
        let settings = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'settings-'"))
        XCTAssertEqual(settings.count, 0, "no tap point or send pan into the mains, so no ›")
        saveScreenshot("main-lr-fedby")

        chip.tap()
        let takeOut = app.alerts["Take Kick out of the main mix?"]
        XCTAssertTrue(takeOut.appears(within: 2))
        takeOut.buttons["Take out"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/01/mix/st") == .int(0) })
        XCTAssertTrue(eventually(within: 2) { chip.label == "Kick out of the main mix" })
    }

    /// The demo's kick and bass feed a mono sub at 0 dB; the rest start off. The On chip switches at once, like a send's.
    func testMainMRowsAreTheMonoSend() {
        launch()
        openMain("Main M")
        let kick = element("/ch/01/mix/mlevel")
        XCTAssertTrue(kick.appears(within: 2))
        XCTAssertEqual(kick.label, "Kick, Ch 1")
        XCTAssertEqual(kick.value as? String, "0.0 dB")
        let snareOn = element("toggle-/ch/02/mix/mono")
        XCTAssertEqual(snareOn.value as? String, "Off")
        XCTAssertFalse(element("fader-note").exists, "a mono level is a send, not the fader")
        saveScreenshot("main-m-fedby")

        snareOn.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/02/mix/mono") == .int(1) })
        XCTAssertTrue(eventually(within: 2) { snareOn.value as? String == "On" })
    }

    private func openMain(_ name: String) {
        app.buttons["Main"].tap()
        open(name)
        app.buttons["Fed by"].tap()
    }
}

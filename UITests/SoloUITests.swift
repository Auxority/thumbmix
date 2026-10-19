import XCTest

/// Solo from the overview (2026-10-19): a soloed strip's name is yellow and says "Solo" wherever it shows.
final class SoloUITests: DeskUITestCase {
    func testSoloedNamesSayItEverywhere() {
        desk.change("/-stat/solosw/01", 1)
        launch()
        XCTAssertTrue(eventually(within: 3) { (app.buttons["Kick"].value as? String) == "1 · Solo" })
        saveScreenshot("solo-overview-look")

        open("Kick")
        XCTAssertTrue(app.staticTexts["Ch 1 · Solo"].appears(within: 2), "the strip's title says it too")
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["Buses"].tap()
        open("Mon 1")
        app.buttons["Fed by"].tap()
        let kick = element("/ch/01/mix/01/level")
        XCTAssertTrue(kick.appears(within: 2))
        XCTAssertEqual(kick.label, "Kick, Ch 1 · Solo")
    }

    /// Solos set anywhere (the desk, another app) bring the bar above the tabs; its Clear is the desk's CLEAR SOLO.
    func testDeskSolosBringTheBarAndClearRemovesThem() {
        launch()
        XCTAssertFalse(element("solo-bar").exists)
        desk.change("/-stat/solosw/01", 1)
        desk.change("/-stat/solosw/49", 1)
        let bar = element("solo-bar")
        XCTAssertTrue(bar.appears(within: 2))
        XCTAssertTrue(eventually(within: 2) { bar.label.contains("2 soloed") })
        saveScreenshot("solo-clear-bar")

        element("clear-solo").tap()

        XCTAssertTrue(
            eventually(within: 3) {
                self.desk.value("/-stat/solosw/01") == .int(0) && self.desk.value("/-stat/solosw/49") == .int(0)
            })
        XCTAssertTrue(eventually(within: 3) { !bar.exists })
    }

    /// The app teaches the hold itself (2026-10-19): the tip shows until the first solo by holding a name.
    func testTipShowsUntilTheFirstHoldSolo() {
        launch(["-tips", "fresh"])
        let tip = app.staticTexts["Solo several at once"]
        XCTAssertTrue(tip.appears(within: 3))
        saveScreenshot("solo-tip")
        app.buttons["Kick"].press(forDuration: 0.6)
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/-stat/solosw/01") == .int(1) })
        XCTAssertTrue(eventually(within: 3) { !tip.exists })

        launch(["-tips", "kept"])
        XCTAssertFalse(tip.appears(within: 2), "learned once, never shown again")
    }

    /// Nothing moves under the thumb when the bar comes in.
    func testTheBarDoesNotMoveTheRows() {
        launch()
        let kick = app.buttons["Kick"]
        let before = kick.frame
        desk.change("/-stat/solosw/02", 1)
        XCTAssertTrue(element("solo-bar").appears(within: 2))
        XCTAssertEqual(kick.frame.minY, before.minY, accuracy: 0.5)
    }
}

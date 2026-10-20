import XCTest

/// Solo from the overview (2026-10-19): a soloed strip's name is yellow and says "Solo" wherever it shows.
final class SoloUITests: DeskUITestCase {
    /// Solos set anywhere (the desk, another app) bring the bar above the tabs, without moving a row under the thumb,
    /// and the soloed names say so on the overview, the strip's title and Fed by. The bar's Clear is the desk's
    /// CLEAR SOLO.
    func testDeskSolosBringTheBarAndClearRemovesThem() {
        launch()
        XCTAssertFalse(element("solo-bar").exists)
        let kickTop = app.buttons["Kick"].frame.minY
        desk.change(soloAddress(1), 1)
        desk.change(soloAddress(49), 1)
        let bar = element("solo-bar")
        XCTAssertTrue(bar.appears(within: 2))
        XCTAssertTrue(eventually(within: 2) { bar.label.contains("2 soloed") })
        XCTAssertEqual(app.buttons["Kick"].frame.minY, kickTop, accuracy: 0.5, "the rows stay put")
        XCTAssertTrue(eventually(within: 3) { (self.app.buttons["Kick"].value as? String) == "1 · Solo" })
        saveScreenshot("solo-clear-bar")

        open("Kick")
        XCTAssertTrue(app.staticTexts["Ch 1 · Solo"].appears(within: 2), "the strip's title says it too")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Buses"].tap()
        open("Mon 1")
        app.buttons["Fed by"].tap()
        let kick = element("/ch/01/mix/01/level")
        XCTAssertTrue(kick.appears(within: 2))
        XCTAssertEqual(kick.label, "Kick, Ch 1 · Solo", "Fed by says it too")
        app.navigationBars.buttons.firstMatch.tap()

        element("clear-solo").tap()
        XCTAssertTrue(eventually(within: 3) { self.solos(1...1, are: 0) && self.solos(49...49, are: 0) })
        XCTAssertTrue(eventually(within: 3) { !bar.exists })
    }

    /// The app teaches the hold itself (2026-10-19): the tip shows until the first solo by holding a name. A hold
    /// solos without opening the strip; a tap still opens it without soloing.
    func testTipShowsUntilTheFirstHoldSolo() {
        launch(["-tips", "fresh"])
        let tip = app.staticTexts["Solo several at once"]
        XCTAssertTrue(tip.appears(within: 3))
        saveScreenshot("solo-tip")
        app.buttons["Kick"].press(forDuration: 0.6)
        XCTAssertTrue(eventually(within: 2) { self.solos(1...1, are: 1) })
        XCTAssertTrue(eventually(within: 2) { (self.app.buttons["Kick"].value as? String) == "1 · Solo" })
        XCTAssertFalse(app.buttons["Mix"].exists, "a hold doesn't open the strip")
        XCTAssertTrue(eventually(within: 3) { !tip.exists }, "the tip went")

        app.buttons["Snare"].tap()
        XCTAssertTrue(app.buttons["Mix"].appears(within: 3), "a tap opens")
        XCTAssertTrue(solos(2...2, are: 0), "without soloing")

        launch(["-tips", "kept"])
        XCTAssertFalse(tip.appears(within: 2), "learned once, never shown again")
    }
}

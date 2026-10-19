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
}

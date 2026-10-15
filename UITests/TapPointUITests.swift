import XCTest

/// A send's tap point (mock D3/S1): the strip's blocks as a chain, lit up to where the send is taken.
@MainActor
final class TapPointUITests: DeskUITestCase {
    private func openSend(_ strip: String, _ address: String) {
        open(strip)
        app.buttons["Sends"].tap()
        let settings = element("settings-" + address)
        XCTAssertTrue(settings.appears(within: 2))
        settings.tap()
    }

    /// The desk keeps one tap point per pair of buses, so an unlinked pair shares one › and one sheet (mock B). The
    /// demo's wedges are fed before the fader. Tapping a block takes the send right after it, Input too, and a second
    /// tap on the current tap point changes nothing.
    func testTappingTheChainSetsThePairsTapPoint() {
        launchAndOpen("Vox 1", tab: "Sends")
        XCTAssertTrue(element("settings-/ch/13/mix/03/level").appears(within: 2), "every pair has a ›")
        XCTAssertFalse(element("settings-/ch/13/mix/02/level").exists, "Mon 2 shares Mon 1's")
        element("settings-/ch/13/mix/01/level").tap()
        XCTAssertTrue(app.buttons["Open Mon 1"].appears(within: 2), "one sheet for the pair")
        XCTAssertTrue(app.buttons["Open Mon 2"].exists)
        XCTAssertTrue(app.staticTexts["Before fader"].exists)
        XCTAssertFalse(element("tap-Pan").exists, "a mono mix has no pan to follow")
        saveScreenshot("tap-point")

        element("tap-Fader").tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(4) })
        XCTAssertTrue(app.staticTexts["After fader"].exists)
        element("tap-Input").tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(0) })
        element("tap-Input").tap()
        element("tap-EQ").tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(2) })
    }

    /// The bus names in a send pair's title are links (mock A): one opens that bus on its Fed by tab, the desk's
    /// sends-on-faders view, with Vox 1 among its sources; Back returns to Vox 1's Sends.
    func testABusNameInTheSheetOpensTheBus() {
        launch()
        openSend("Vox 1", "/ch/13/mix/01/level")
        let mon2 = app.buttons["Open Mon 2"]
        XCTAssertTrue(mon2.appears(within: 2))
        mon2.tap()
        XCTAssertTrue(app.staticTexts["Bus 2"].appears(within: 3), "Mon 2's own screen")
        XCTAssertTrue(app.buttons["Fed by"].isSelected)
        XCTAssertTrue(
            eventually(within: 2) { self.element("/ch/13/mix/02/level").isHittable },
            "Vox 1's send to Mon 2 is in view, though it's the 13th source")
        saveScreenshot("goto-bus")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ch 13"].appears(within: 3))
        XCTAssertTrue(app.buttons["Sends"].isSelected, "back where it left")
    }

    /// A mono mix's chain ends in Group, so a Subgroup set on the desk doesn't look like After fader.
    func testAMonoMixCanBeASubgroup() {
        desk.change("/ch/13/mix/01/type", 5)
        launch()
        openSend("Vox 1", "/ch/13/mix/01/level")
        XCTAssertTrue(app.staticTexts["Subgroup"].appears(within: 2))
        XCTAssertEqual(element("tap-Group").value as? String, "In this mix")
        XCTAssertTrue(element("tap-Group").isSelected)

        element("tap-Fader").tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(4) })
        element("tap-Group").tap()
        app.alerts.buttons["Make subgroup"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(5) })
    }

    /// Subgroup puts the send at a fixed 0 dB, so it asks first; Cancel leaves the desk alone.
    func testSubgroupAsksFirst() {
        desk.change("/config/buslink/5-6", 1)
        launch()
        openSend("Vox 1", "/ch/13/mix/05/level")
        let pan = element("tap-Pan")
        XCTAssertTrue(pan.appears(within: 2), "a stereo mix's chain ends in Pan")

        // The explanation keeps the longest one's room, so the pans below it never move.
        let panRow = element("/ch/13/mix/05/pan")
        let panTop = panRow.frame.minY
        for block in ["tap-EQ", "tap-Input", "tap-Fader"] { element(block).tap() }
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/05/type") == .int(4) })
        XCTAssertEqual(panRow.frame.minY, panTop)

        pan.tap()
        XCTAssertTrue(app.alerts["Make this send a subgroup?"].appears(within: 2))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(desk.value("/ch/13/mix/05/type"), .int(4))

        pan.tap()
        XCTAssertTrue(app.alerts.buttons["Make subgroup"].appears(within: 2))
        app.alerts.buttons["Make subgroup"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/05/type") == .int(5) })
        // The sheet's Level row, not the same send's row in the list behind it.
        let level = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label == %@", "/ch/13/mix/05/level", "Level")).firstMatch
        XCTAssertTrue(eventually(within: 2) { !level.isEnabled }, "the level is fixed")
        saveScreenshot("tap-point-subgroup")

        // A subgroup takes the channel's own pan, so the send's pan settings step aside too.
        app.staticTexts["Subgroup"].swipeUp()
        let follow = app.switches["follow-/ch/13/mix/05/panFollow"]
        XCTAssertTrue(follow.appears(within: 2))
        XCTAssertFalse(follow.isEnabled)
        saveScreenshot("tap-point-subgroup-pans")
    }
}

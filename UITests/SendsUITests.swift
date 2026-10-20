import XCTest

/// Sends: an input's to the buses, a bus's or main's to the matrices (mock B), the send's tap point (mock D3/S1: the
/// strip's blocks as a chain, lit up to where the send is taken), and the Fed by tabs, the mains' included.
@MainActor
final class SendsUITests: DeskUITestCase {
    /// Sends list the buses by name. The desk keeps one tap point per pair of buses, so an unlinked pair shares one ›
    /// and one sheet (mock B); the demo's wedges are fed before the fader. Tapping a block takes the send right after
    /// it, Input too, and a second tap on the current tap point changes nothing. A mono mix's chain ends in Group, so a
    /// subgroup doesn't look like After fader. The bus names in the title are links (mock A): one opens that bus on
    /// its Fed by tab, the desk's sends-on-faders view, with Vox 1 among its sources; Back returns to Vox 1's Sends.
    func testAnInputsSendsToTheBuses() {
        launchAndOpen("Vox 1", tab: "Sends")
        let toMon1 = element("/ch/13/mix/01/level")
        XCTAssertTrue(toMon1.appears(within: 2))
        XCTAssertEqual(toMon1.label, "Mon 1, Bus 1")
        XCTAssertEqual(toMon1.value as? String, "0.0 dB")

        XCTAssertTrue(element("settings-/ch/13/mix/03/level").exists, "every pair has a ›")
        XCTAssertFalse(element("settings-/ch/13/mix/02/level").exists, "Mon 2 shares Mon 1's")
        element("settings-/ch/13/mix/01/level").tap()
        XCTAssertTrue(app.buttons["Open Mon 1"].appears(within: 2), "one sheet for the pair")
        XCTAssertTrue(app.buttons["Open Mon 2"].exists)
        XCTAssertTrue(app.staticTexts["Before fader"].exists)
        XCTAssertFalse(element("tap-Pan").exists, "a mono mix has no pan to follow")
        saveScreenshot("tap-point")
        element("tap-Fader").tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(4) }, "After fader")
        XCTAssertTrue(app.staticTexts["After fader"].exists)
        element("tap-Input").tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(0) }, "after Input")
        element("tap-Input").tap()
        element("tap-EQ").tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(2) }, "after EQ")

        element("tap-Group").tap()
        app.alerts.buttons["Make subgroup"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/01/type") == .int(5) }, "a subgroup")
        XCTAssertTrue(app.staticTexts["Subgroup"].appears(within: 2))
        XCTAssertEqual(element("tap-Group").value as? String, "In this mix")
        XCTAssertTrue(element("tap-Group").isSelected)

        let mon2 = app.buttons["Open Mon 2"]
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

    /// A linked bus pair is one send, and its › opens the pan settings (mock H): the pan and Follow LR pan reach the
    /// desk, and while the send follows the LR pan its own pan can't be dragged. Subgroup puts the send at a fixed
    /// 0 dB, so it asks first. A linked source (the demo's Gtr L/R) keeps a send pan per side, as it keeps its LR pan.
    func testALinkedBusPairIsOneSendWithPanSettings() {
        desk.change("/config/buslink/5-6", 1)
        launchAndOpen("Vox 1", tab: "Sends")
        let toPair = element("/ch/13/mix/05/level")
        XCTAssertTrue(toPair.appears(within: 2))
        XCTAssertEqual(toPair.label, "Bus 5-6")
        XCTAssertFalse(element("/ch/13/mix/06/level").exists, "the even bus is part of the pair's send")
        XCTAssertFalse(element("settings-/ch/13/mix/02/level").exists, "an even send has no tap point of its own")

        element("settings-/ch/13/mix/05/level").tap()
        let pan = element("/ch/13/mix/05/pan")
        XCTAssertTrue(pan.appears(within: 2))
        XCTAssertEqual(pan.value as? String, "C")
        drag(pan)
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/05/pan") != .float(0.5) }, "the pan reached the desk")
        let follow = app.switches["follow-/ch/13/mix/05/panFollow"]
        follow.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/05/panFollow") == .int(1) })
        XCTAssertTrue(eventually(within: 2) { !pan.isEnabled }, "the desk ignores the send's own pan now")
        saveScreenshot("send-sheet")

        makeTheStereoSendASubgroup(pan: pan, follow: follow)
        app.buttons["Done"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        eachSideOfGtrKeepsItsSendPan()
    }

    /// Subgroup puts the send at a fixed 0 dB and takes the channel's own pan, so it asks first.
    private func makeTheStereoSendASubgroup(pan: XCUIElement, follow: XCUIElement) {
        let tapPan = element("tap-Pan")
        XCTAssertTrue(tapPan.exists, "a stereo mix's chain ends in Pan")
        // The explanation keeps the longest one's room, so the pans below it never move.
        let panTop = pan.frame.minY
        for block in ["tap-EQ", "tap-Input", "tap-Fader"] { element(block).tap() }
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/05/type") == .int(4) })
        XCTAssertEqual(pan.frame.minY, panTop, "the pans stay put")
        tapPan.tap()
        XCTAssertTrue(app.alerts["Make this send a subgroup?"].appears(within: 2))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(desk.value("/ch/13/mix/05/type"), .int(4), "Cancel leaves the desk alone")
        Thread.sleep(forTimeInterval: 0.4)
        tapPan.tap()
        XCTAssertTrue(app.alerts.buttons["Make subgroup"].appears(within: 2))
        app.alerts.buttons["Make subgroup"].tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/13/mix/05/type") == .int(5) })
        // The sheet's Level row, not the same send's row in the list behind it.
        let level = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label == %@", "/ch/13/mix/05/level", "Level")).firstMatch
        XCTAssertTrue(eventually(within: 2) { !level.isEnabled }, "a subgroup's level is fixed")
        saveScreenshot("tap-point-subgroup")
        // A subgroup takes the channel's own pan, so the send's pan settings step aside too.
        app.staticTexts["Subgroup"].swipeUp()
        XCTAssertTrue(follow.appears(within: 2))
        XCTAssertFalse(follow.isEnabled, "a subgroup has no Follow LR pan")
        saveScreenshot("tap-point-subgroup-pans")
    }

    private func eachSideOfGtrKeepsItsSendPan() {
        app.swipeUp()
        open("Gtr")
        app.buttons["Sends"].tap()
        element("settings-/ch/09/mix/05/level").tap()
        let left = element("/ch/09/mix/05/pan")
        XCTAssertTrue(left.appears(within: 2))
        XCTAssertEqual(left.label, "Pan · Gtr L")
        XCTAssertEqual(element("/ch/10/mix/05/pan").label, "Pan · Gtr R")
        saveScreenshot("send-sheet-pair")
        drag(left)
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/09/mix/05/pan") != .float(0.5) })
        XCTAssertEqual(desk.value("/ch/10/mix/05/pan"), .float(0.5), "the right side's pan stays its own")
    }

    private func drag(_ row: XCUIElement) {
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)))
    }

    /// A bus's Sends sit before Fed by, which keeps the far right: mix buses use it more. Fed by lists every source,
    /// each named source with its desk number like the overview (2026-10-13), its On chip tinted, not filled (a send
    /// is on almost all show, and fills mean "look here"). The demo's linked Gtr L/R is one row, held by its odd side.
    /// Unlinked on the desk while a finger holds that row, the rows hold still under the finger (`SteadyRows`;
    /// XCUITest can't look during a hold) and split once it lifts, never stuck as they were.
    func testABusSendsToTheMatricesAndIsFedBy() {
        launchAndOpen("Mon 1", group: "Buses")
        let sends = app.buttons["Sends"]
        XCTAssertTrue(sends.exists)
        XCTAssertLessThan(sends.frame.minX, app.buttons["Fed by"].frame.minX, "Sends before Fed by")
        sends.tap()
        let toFill = element("/bus/01/mix/01/level")
        XCTAssertTrue(toFill.appears(within: 2))
        XCTAssertEqual(toFill.label, "Fill, Matrix 1")
        XCTAssertEqual(toFill.value as? String, "−∞ dB")
        XCTAssertTrue(element("/bus/01/mix/06/level").exists, "all six matrices")
        saveScreenshot("bus-sends")

        app.buttons["Fed by"].tap()
        let vox = element("/ch/13/mix/01/level")
        XCTAssertTrue(vox.appears(within: 2))
        XCTAssertEqual(vox.value as? String, "0.0 dB")
        XCTAssertEqual(vox.label, "Vox 1, Ch 13")
        XCTAssertTrue(element("/fxrtn/01/mix/01/level").exists)
        XCTAssertEqual(element("/ch/20/mix/01/level").label, "Ch 20", "unused inputs show while the fold is open")
        let on = element("toggle-/ch/01/mix/01/on")
        XCTAssertEqual(on.value as? String, "On")
        assertFillIsTint(on)
        assertLabelContrasts(on)
        saveScreenshot("task-16-fedby")

        let pair = element("/ch/09/mix/01/level")
        XCTAssertEqual(pair.label, "Gtr, Ch 9-10")
        XCTAssertFalse(element("/ch/10/mix/01/level").exists, "the even side has no row of its own")
        // The 9th source sits below the screen's edge: scroll four rows, starting on a visible row.
        element("/ch/05/mix/01/level").press(forDuration: 0.05, thenDragTo: element("/ch/01/mix/01/level"))
        XCTAssertTrue(eventually(within: 2) { pair.isHittable })
        let desk = self.desk!
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) { desk.change("/config/chlink/9-10", 0) }
        pair.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(
                forDuration: 0.05, thenDragTo: pair.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)),
                withVelocity: .slow, thenHoldForDuration: 2)
        XCTAssertTrue(
            eventually(within: 3) { self.element("/ch/10/mix/01/level").exists }, "the pair split once lifted")
        XCTAssertNotEqual(element("/ch/09/mix/01/level").value as? String, "−∞ dB", "the drag moved the send")
    }

    /// The mains send to the matrices; the demo's Fill (Matrix 1) takes the main mix at 0 dB. Their Fed by (mocks A, F1
    /// and F4, 2026-10-13): Main LR's rows are each strip's LR switch and own fader, captioned "Fader" under a note
    /// saying so, and the LR chip asks first, like the Mix tab's pill (a stray tap while scrolling can drop a vocal
    /// from the PA). Main M's are the mono send, On and level, like a bus's: the demo's kick and bass feed a mono sub at
    /// 0 dB. A matrix is fed by the buses and the mains, and has no LR switch on the desk.
    func testTheMainsAndMatrices() {
        launch()
        app.buttons["Main"].tap()
        open("LR")
        app.buttons["Sends"].tap()
        let toFill = element("/main/st/mix/01/level")
        XCTAssertTrue(toFill.appears(within: 2))
        XCTAssertEqual(toFill.label, "Fill, Matrix 1")
        XCTAssertEqual(toFill.value as? String, "0.0 dB")

        mainLRIsFedByEachStripsFader()
        app.navigationBars.buttons.firstMatch.tap()
        mainMIsFedByTheMonoSends()
        app.navigationBars.buttons.firstMatch.tap()
        aMatrixIsFedByTheBusesAndMains()
    }

    private func mainLRIsFedByEachStripsFader() {
        app.buttons["Fed by"].tap()
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

    private func mainMIsFedByTheMonoSends() {
        open("Main M")
        app.buttons["Fed by"].tap()
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

    private func aMatrixIsFedByTheBusesAndMains() {
        app.buttons["Matrix"].tap()
        open("Fill")
        XCTAssertTrue(element("solo-/-stat/solosw/65").appears(within: 2))
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "mainLR-/mtx/01/mix/st").firstMatch.exists,
            "a matrix has no LR switch")
        app.buttons["Fed by"].tap()
        let fromMain = element("/main/st/mix/01/level")
        XCTAssertTrue(fromMain.appears(within: 2))
        XCTAssertEqual(fromMain.label, "LR, Main LR")
        XCTAssertEqual(fromMain.value as? String, "0.0 dB")
        XCTAssertTrue(element("/bus/01/mix/01/level").exists)
        XCTAssertFalse(element("/ch/01/mix/01/level").exists, "inputs feed buses, not matrices")
        saveScreenshot("matrix-fedby")
    }
}

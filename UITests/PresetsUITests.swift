import XCTest

/// Save a strip's settings as a preset, load them back after the desk changed, and see what a strip can't take.
/// A file comes in as a source on Sources (`PresetSourcesUITests`), not by an Import button. `-isolatedPresets` gives each run its own folder.
@MainActor
final class PresetsUITests: DeskUITestCase {
    private let gain = "/headamp/032/gain"
    private let phantom = "/headamp/032/phantom"
    private let bandGain = "/ch/01/eq/1/g"

    /// One walk: the desk's gain is lowered, 48V switched on and a band moved after the save. Loading asks about the
    /// gain (Keep), then 48V (Turn Off); the band comes back at the desk; the gain stays where the engineer put it.
    func testASavedKickLoadsBackAndAsksAboutGainAnd48V() {
        desk.change(gain, float: 0.5)
        launch(["-isolatedPresets", "YES"])
        open("Kick")
        saveKickTest()

        desk.change(gain, float: 0.3)
        desk.change(phantom, 1)
        desk.change(bandGain, float: 0.9)
        XCTAssertTrue(eventually(within: 3) { self.desk.value(self.bandGain) == .float(0.9) })

        loadKickTest()
        XCTAssertTrue(eventually(within: 3) { self.desk.value(self.bandGain) == .float(0.5) }, "the band came back")
        XCTAssertTrue(eventually(within: 3) { self.desk.value(self.phantom) == .int(0) }, "48V turned off, as confirmed")
        XCTAssertEqual(desk.value(gain), .float(0.3), "Keep left the gain where it was")
        // A load closes the presets and the edit sheet: the strip shows what loaded (the user, 2026-10-29).
        XCTAssertTrue(eventually(within: 3) { !self.element("presets-row").exists }, "the edit sheet closed")
        XCTAssertTrue(app.buttons["edit-strip"].isHittable, "back on the strip")

        openPresets()
        element("preset-row-Kick test").tap()
        XCTAssertTrue(element("preset-fits").appears(within: 3))
        XCTAssertTrue(element("preset-fits").label.contains("Kick (Ch 1)"), "the strips whose names fit")
        saveScreenshot("preset-page")
        allValuesOpenFromACard()

        aBusCannotTakeTheInputOrTheEQOfAChannel()
    }

    /// A preset that keeps everything a channel can hold gets a card per part, in the strip's tab order, and each
    /// card opens its values.
    func testAPresetWithEveryPartShowsACardForEach() {
        launch(["-isolatedPresets", "YES"])
        open("Kick")
        openPresets()
        element("presets-save").tap()
        // Mix and Sends start unticked in the save sheet: tick them so the preset holds every part.
        for part in ["mix", "sends"] {
            let toggle = element("keep-" + part)
            XCTAssertTrue(eventually(within: 5) { toggle.isEnabled }, "\(part) was read")
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        element("preset-save-confirm").tap()
        let row = element("preset-row-Kick")
        XCTAssertTrue(row.appears(within: 3))
        row.tap()
        swipeDownLeavesTheEditSheetOpen()

        for part in ["input", "eq", "gate", "comp", "mix", "sends"] {
            XCTAssertTrue(element("preset-part-" + part).appears(within: 3), part)
            XCTAssertTrue(element("load-" + part).exists, "a chip for \(part)")
        }
        saveScreenshot("preset-every-part-top")
        app.swipeUp()
        saveScreenshot("preset-every-part-bottom")
        element("preset-part-comp").tap()
        XCTAssertTrue(element("preset-group-0").appears(within: 3))
        saveScreenshot("preset-values-comp")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()

        // A colour picked but not yet sent with Done: a load goes back to the edit sheet, so the pick isn't lost.
        // Green: Kick is red on the fake desk, and picking its own colour again is no change.
        let green = app.buttons["color-green"]
        XCTAssertTrue(green.appears(within: 3))
        green.tap()
        element("presets-row").tap()
        element("preset-row-Kick").tap()
        let load = element("preset-load")
        XCTAssertTrue(eventually(within: 5) { load.exists && load.isEnabled })
        load.tap()
        XCTAssertTrue(element("presets-row").appears(within: 5), "back on the edit sheet")
        XCTAssertTrue(green.isSelected, "the unsent colour is still picked")
    }

    /// Only Cancel, Done and a load close the edit sheet (the user, 2026-10-30): a swipe down on a preset closed it all.
    private func swipeDownLeavesTheEditSheetOpen() {
        let card = element("preset-part-input")
        XCTAssertTrue(card.appears(within: 3))
        card.swipeDown()
        // Long enough for a dismissal to finish, so the check below can't pass mid-animation.
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(card.isHittable, "a swipe down left the preset open")
    }

    private func openPresets() {
        app.buttons["edit-strip"].tap()
        let row = element("presets-row")
        XCTAssertTrue(row.appears(within: 3))
        row.tap()
        XCTAssertTrue(element("presets-save").appears(within: 3))
        XCTAssertFalse(app.buttons["Import a preset file…"].exists, "a file comes in as a source")
    }

    private func saveKickTest() {
        openPresets()
        element("presets-save").tap()
        let name = app.textFields["preset-name"]
        XCTAssertTrue(name.appears(within: 3))
        name.tap()
        name.clearText()
        name.typeText("Kick test")
        // Gate and comp stay unticked: this preset holds the input and the EQ.
        for part in ["gate", "comp"] {
            let toggle = element("keep-" + part)
            XCTAssertTrue(eventually(within: 5) { toggle.isEnabled }, "\(part) was read")
            // The row's middle is its label; the switch is at its right end.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        XCTAssertTrue(eventually(within: 5) { self.element("keep-input").isEnabled && self.element("keep-eq").isEnabled })
        saveScreenshot("preset-save")
        element("preset-save-confirm").tap()
        XCTAssertTrue(element("preset-row-Kick test").appears(within: 3), "listed under its name")
    }

    private func loadKickTest() {
        element("preset-row-Kick test").tap()
        // The parts to load are chips on the page itself, above Load (pick F, 2026-10-28): no sheet in between.
        let load = element("preset-load")
        XCTAssertTrue(eventually(within: 5) { load.exists && load.isEnabled })
        XCTAssertTrue(element("load-eq").isEnabled)
        saveScreenshot("preset-load")
        load.tap()

        let raise = app.alerts.firstMatch
        XCTAssertTrue(raise.appears(within: 3))
        XCTAssertTrue(raise.label.hasPrefix("Raise the gain of Kick"), raise.label)
        raise.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Keep'")).firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let power = app.alerts["Turn off 48V for Kick?"]
        XCTAssertTrue(power.appears(within: 3))
        power.buttons["Turn Off"].tap()
        XCTAssertTrue(eventually(within: 3) { !self.app.alerts.firstMatch.exists })
    }

    /// A card opens its part's every value: the EQ as a table of bands, in the desk's type names.
    private func allValuesOpenFromACard() {
        element("preset-part-eq").tap()
        let bands = element("preset-bands")
        XCTAssertTrue(bands.appears(within: 3))
        XCTAssertTrue(element("load-eq").exists, "the chips stay on a part's page")
        saveScreenshot("preset-values-eq")
        app.navigationBars.buttons.firstMatch.tap()
        // The saved Kick holds Input and EQ only: the save above left Gate and Comp out.
        let input = element("preset-part-input")
        XCTAssertTrue(input.appears(within: 3))
        input.tap()
        XCTAssertTrue(element("preset-group-0").appears(within: 3))
        saveScreenshot("preset-values-input")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("preset-load").appears(within: 3))
    }

    /// A bus has no Input tab, and its EQ has six bands where a channel's has four.
    private func aBusCannotTakeTheInputOrTheEQOfAChannel() {
        XCUIDevice.shared.system.open(URL(string: "thumbmix-test://connect?port=\(desk.port)")!)
        let buses = app.buttons["Buses"]
        XCTAssertTrue(eventually(within: 10) { buses.exists && buses.isEnabled })
        buses.tap()
        open("Mon 1")
        openPresets()
        XCTAssertTrue(element("preset-row-Kick test").appears(within: 3), "listed under Others: no strip here is named kick")
        saveScreenshot("presets-list")
        element("preset-row-Kick test").tap()
        let input = element("load-input")
        XCTAssertTrue(input.appears(within: 3))
        XCTAssertFalse(input.isEnabled, "buses have no Input tab")
        XCTAssertFalse(element("load-eq").isEnabled, "a channel's 4 bands are not a bus's 6")
        XCTAssertFalse(element("load-gate").exists, "the preset was saved without its gate")
        XCTAssertFalse(element("load-comp").exists, "nor its comp")
        XCTAssertEqual(element("preset-load").label, "Load onto Mon 1", "nothing can load: no count, and no raw markup")
        saveScreenshot("preset-load-bus")
    }
}

extension XCUIElement {
    /// Deletes what a text field holds, as a thumb would.
    fileprivate func clearText() {
        guard let text = value as? String, !text.isEmpty else { return }
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
    }
}

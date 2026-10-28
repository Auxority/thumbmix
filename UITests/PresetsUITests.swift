import XCTest

/// Save a strip's settings as a preset, load them back after the desk changed, and see what a strip can't take.
/// Importing a file stays in Core tests: no Files picker here. `-isolatedPresets` gives each run its own folder.
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
        XCTAssertTrue(element("preset-fits").label.contains("Kick (Ch 1)"), "the strips whose names fit")
        saveScreenshot("preset-page")

        aBusCannotTakeTheInputOrTheEQOfAChannel()
    }

    private func openPresets() {
        app.buttons["edit-strip"].tap()
        let row = element("presets-row")
        XCTAssertTrue(row.appears(within: 3))
        row.tap()
        XCTAssertTrue(element("presets-save").appears(within: 3))
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
        let load = element("preset-load")
        XCTAssertTrue(load.appears(within: 3))
        load.tap()
        let confirm = element("preset-load-confirm")
        XCTAssertTrue(eventually(within: 5) { confirm.exists && confirm.isEnabled })
        saveScreenshot("preset-load")
        confirm.tap()

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
        let load = element("preset-load")
        XCTAssertTrue(load.appears(within: 3))
        load.tap()
        let input = element("load-input")
        XCTAssertTrue(input.appears(within: 3))
        XCTAssertFalse(input.isEnabled, "buses have no Input tab")
        XCTAssertFalse(element("load-eq").isEnabled, "a channel's 4 bands are not a bus's 6")
        XCTAssertFalse(element("load-gate").exists, "the preset was saved without its gate")
        XCTAssertFalse(element("load-comp").exists, "nor its comp")
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

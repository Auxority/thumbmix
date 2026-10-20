import XCTest

/// The desk's six mute groups on the Main page, and the red-bordered M of a strip a group mutes. The demo desk has the
/// drums (Ch 1-7) in group 1 and the vocals (Ch 13-14) in group 2, every group off.
@MainActor
final class MuteGroupUITests: DeskUITestCase {
    /// The Main page switches a group, names each group by its strips, and disables a group the desk never answered
    /// for. A group switched on the desk borders its strips' M. A hold opens who's in a group.
    func testTheMainPageSwitchesAGroup() {
        desk.forget("/config/mute/3")
        launch()
        app.buttons["Main"].tap()
        theMainPageSwitchesGroupOne()
        aGroupOnTheDeskBordersItsStripsM()
        app.buttons["Main"].tap()
        holdingAGroupOpensWhoIsInIt()
    }

    /// A tap switches the group on the desk at once and back; all six fit above the pills with the mains in view.
    /// A desk mute group has no name: its button names its strips instead, or says it's empty. A group the desk never
    /// answered for is disabled, also to VoiceOver, not a real "Off".
    private func theMainPageSwitchesGroupOne() {
        let group = element("mute-group-1")
        XCTAssertTrue(group.appears(within: 3))
        XCTAssertTrue(element("mute-group-6").isHittable, "the grid fits the iPhone SE")
        XCTAssertTrue(app.buttons["LR"].isHittable, "the mains stay in view above it")
        XCTAssertTrue(group.label.contains("Kick"), group.label)
        XCTAssertTrue(element("mute-group-4").label.contains("empty"), element("mute-group-4").label)
        XCTAssertFalse(element("mute-group-3").isEnabled, "unread, not Off")
        group.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/config/mute/1") == .int(1) })
        XCTAssertTrue(eventually(within: 2) { group.value as? String == "On" })
        saveScreenshot("mute-groups")
        group.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/config/mute/1") == .int(0) })
    }

    /// The border is the only sign a group is on outside the Main page, so it says so in words to VoiceOver too.
    private func aGroupOnTheDeskBordersItsStripsM() {
        // The app's own tap holds the address for a moment: the desk's change after it must wait that out.
        Thread.sleep(forTimeInterval: 1)
        desk.change("/config/mute/1", 1)
        app.buttons["Inputs"].tap()
        let kick = element("mute-/ch/01/mix/on")
        XCTAssertTrue(eventually(within: 3) { kick.value as? String == "Muted by a mute group" })
        XCTAssertEqual(element("mute-/ch/08/mix/on").value as? String, "", "Bass is in no group")
        saveScreenshot("group-muted-m")
    }

    /// A hold opens who's in the group instead of switching it: a press a bit too slow changes nothing on the desk.
    /// A chip applies at once and keeps the strip's other groups; a second tap takes it out again.
    private func holdingAGroupOpensWhoIsInIt() {
        let group = element("mute-group-2")
        XCTAssertTrue(group.appears(within: 3))
        group.press(forDuration: 1.0)
        XCTAssertTrue(app.navigationBars["Mute group 2"].appears(within: 3))
        let vox = element("mute-assign-/ch/13")
        XCTAssertTrue(vox.appears(within: 3))
        XCTAssertEqual(vox.value as? String, "Assigned")
        let bass = element("mute-assign-/ch/08")
        XCTAssertEqual(bass.value as? String, "Not assigned", "Bass")
        saveScreenshot("mute-group-members")
        bass.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/08/grp/mute") == .int(0b10) }, "Bass joins")
        bass.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/08/grp/mute") == .int(0) }, "and leaves")

        // Back on Main, long after any send a tap on release would have made: the group is still off.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(group.appears(within: 3))
        XCTAssertEqual(group.value as? String, "Off", "the hold didn't switch the group")
        XCTAssertEqual(desk.value("/config/mute/2"), .int(0))
    }
}

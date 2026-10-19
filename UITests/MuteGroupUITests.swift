import XCTest

/// The desk's six mute groups on the Main page, and the red-bordered M of a strip a group mutes. The demo desk has the
/// drums (Ch 1-7) in group 1 and the vocals (Ch 13-14) in group 2, every group off.
@MainActor
final class MuteGroupUITests: DeskUITestCase {
    /// The border is the only sign a group is on outside the Main page, so it says so in words to VoiceOver too.
    func testAGroupOnTheDeskBordersItsStripsM() {
        desk.change("/config/mute/1", 1)
        launch()
        let kick = element("mute-/ch/01/mix/on")
        XCTAssertTrue(eventually(within: 3) { kick.value as? String == "Muted by a mute group" })
        XCTAssertEqual(element("mute-/ch/08/mix/on").value as? String, "", "Bass is in no group")
        saveScreenshot("group-muted-m")
    }

    /// A tap switches the group on the desk at once and back; all six fit above the pills with the mains in view.
    func testTheMainPageSwitchesAGroup() {
        launch()
        app.buttons["Main"].tap()
        let group = element("mute-group-1")
        XCTAssertTrue(group.appears(within: 3))
        XCTAssertTrue(element("mute-group-6").isHittable, "the grid fits the iPhone SE")
        XCTAssertTrue(app.buttons["LR"].isHittable, "the mains stay in view above it")
        group.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/config/mute/1") == .int(1) })
        XCTAssertTrue(eventually(within: 2) { group.value as? String == "On" })
        saveScreenshot("mute-groups")
        group.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/config/mute/1") == .int(0) })
    }

    /// A desk mute group has no name: its button names its strips instead, or says it's empty.
    func testAGroupNamesItsStrips() {
        launch()
        app.buttons["Main"].tap()
        let drums = element("mute-group-1")
        XCTAssertTrue(drums.appears(within: 3))
        XCTAssertTrue(drums.label.contains("Kick"), drums.label)
        XCTAssertTrue(element("mute-group-4").label.contains("empty"), element("mute-group-4").label)
    }

    /// A hold opens who's in the group instead of switching it: a press a bit too slow changes nothing on the desk.
    func testHoldingAGroupOpensWhoIsInIt() {
        openMuteGroup(2)
        let vox = element("mute-assign-/ch/13")
        XCTAssertTrue(vox.appears(within: 3))
        XCTAssertEqual(vox.value as? String, "Assigned")
        XCTAssertEqual(element("mute-assign-/ch/08").value as? String, "Not assigned", "Bass")
        saveScreenshot("mute-group-members")
        // Back on Main, long after any send a tap on release would have made: the group is still off.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let group = element("mute-group-2")
        XCTAssertTrue(group.appears(within: 3))
        XCTAssertEqual(group.value as? String, "Off", "the hold didn't switch the group")
        XCTAssertEqual(desk.value("/config/mute/2"), .int(0))
    }

    /// A tap applies at once and keeps the strip's other groups; a second tap takes it out again.
    func testAChipAddsAStripAtOnce() {
        openMuteGroup(2)
        let bass = element("mute-assign-/ch/08")
        XCTAssertTrue(bass.appears(within: 3))
        bass.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/08/grp/mute") == .int(0b10) })
        bass.tap()
        XCTAssertTrue(eventually(within: 2) { self.desk.value("/ch/08/grp/mute") == .int(0) })
    }

    /// Matrices and the mains can be in a mute group; DCAs can't.
    func testTheMembersScreenListsMatricesAndMains() {
        openMuteGroup(1)
        XCTAssertTrue(element("mute-assign-/ch/01").appears(within: 3))
        XCTAssertTrue(element("mute-assign-/mtx/01").exists)
        XCTAssertTrue(element("mute-assign-/main/st").exists)
        XCTAssertFalse(element("mute-assign-/dca/1").exists)
    }

    /// A group the desk never answered for is disabled, also to VoiceOver, not a real "Off".
    func testAnUnreadGroupIsDisabled() {
        desk.forget("/config/mute/3")
        launch()
        app.buttons["Main"].tap()
        let group = element("mute-group-3")
        XCTAssertTrue(group.appears(within: 3))
        XCTAssertFalse(group.isEnabled)
        XCTAssertTrue(element("mute-group-1").isEnabled)
    }

    /// The header counts the group's strips in words that agree: "1 strip", not "1 strips".
    func testAHeaderCountsOneStrip() {
        desk.change("/ch/14/grp/mute", 0)
        openMuteGroup(2)
        let header = element("mute-group-header")
        XCTAssertTrue(header.appears(within: 3))
        XCTAssertTrue(header.label.contains("1 strip"), header.label)
        XCTAssertFalse(header.label.contains("strips"), header.label)
    }

    private func openMuteGroup(_ group: Int) {
        launch()
        app.buttons["Main"].tap()
        let button = element("mute-group-\(group)")
        XCTAssertTrue(button.appears(within: 3))
        button.press(forDuration: 1.0)
        XCTAssertTrue(app.navigationBars["Mute group \(group)"].appears(within: 3))
    }
}

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
}

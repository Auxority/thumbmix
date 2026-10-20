import XCTest

/// The EQ tab's live spectrum: the desk's RTA, borrowed for the open channel.
@MainActor
final class SpectrumUITests: DeskUITestCase {
    /// The EQ tab borrows the desk's RTA for this channel; the status line shows once spectrum data arrives. It used to
    /// appear only then, pushing everything under it down a line: Reset bands showed for a moment, then jumped.
    func testNothingMovesWhenTheSpectrumArrives() {
        launchAndOpen("Kick", tab: "EQ")
        let reset = app.buttons["Reset bands"]
        XCTAssertTrue(reset.appears(within: 2))
        let before = reset.frame.minY
        let status = app.staticTexts["rta-status"]
        XCTAssertTrue(eventually(within: 5) { status.exists && status.label == "RTA follows Kick (after EQ)" })
        saveScreenshot("eq-spectrum")
        XCTAssertEqual(reset.frame.minY, before, accuracy: 0.5, "Reset bands stayed put")
    }

    /// Coming back from another app rebuilds the link; the RTA must be borrowed again once it is live.
    func testTheSpectrumComesBackAfterTheBackground() {
        launchAndOpen("Kick", tab: "EQ")
        let status = app.staticTexts["rta-status"]
        XCTAssertTrue(eventually(within: 5) { status.exists && status.label == "RTA follows Kick (after EQ)" })
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(eventually(within: 5) { [.runningBackground, .runningBackgroundSuspended].contains(self.app.state) })
        app.activate()
        XCTAssertTrue(eventually(within: 10) { status.exists && status.label == "RTA follows Kick (after EQ)" })
    }
}

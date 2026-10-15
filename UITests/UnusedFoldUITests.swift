import XCTest

/// Unused strips fold into one row at the end of the overview, Sends and Fed by; Show puts them back in their desk
/// spots, dimmed (mocks 2026-10-14-unused-strips). The demo's Ch 15-16 and 18-32 are unnamed with their fader down.
@MainActor
final class UnusedFoldUITests: DeskUITestCase {
    override class var showsUnusedStrips: Bool { false }

    func testTheOverviewFoldsUnusedStripsAndShowsThemInPlace() {
        launch()
        let fold = foldClosed()
        XCTAssertFalse(app.buttons["Ch 20"].exists)
        XCTAssertTrue(app.buttons["Gtr"].exists, "a used strip stays")
        fold.tap()
        XCTAssertTrue(app.buttons["Ch 20"].appears(within: 2))
        XCTAssertEqual(fold.label, "Hide unused")
        saveScreenshot("unused-open")
        fold.tap()
        XCTAssertTrue(eventually(within: 2) { !self.app.buttons["Ch 20"].exists })
    }

    /// Rows come and go above the fold row; the row itself stays under the finger (the user, 2026-10-14).
    func testShowAndHideLeaveTheFoldRowWhereItWas() {
        launch()
        let fold = foldClosed()
        // From a strip's name, not its fader: a drag there would move the fader.
        app.buttons["Tom 2"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)))
        XCTAssertTrue(eventually(within: 2) { fold.isHittable })
        saveScreenshot("unused-closed")
        let top = fold.frame.minY
        fold.tap()
        XCTAssertTrue(eventually(within: 2) { fold.label == "Hide unused" && abs(fold.frame.minY - top) < 2 }, "after Show")
        fold.tap()
        XCTAssertTrue(eventually(within: 2) { fold.label == "Show unused" && abs(fold.frame.minY - top) < 2 }, "after Hide")
    }

    /// Ch 21 is unnamed with its fader down, but its send to Mon 1 is up: Fed by keeps it in reach (#67).
    func testFedByKeepsAnUnusedSourceWhoseSendIsUp() {
        desk.change("/ch/21/mix/01/level", float: 0.6)
        launchAndOpen("Mon 1", group: "Buses")
        app.buttons["Fed by"].tap()
        XCTAssertTrue(element("/ch/21/mix/01/level").appears(within: 2))
        XCTAssertFalse(element("/ch/22/mix/01/level").exists)
        XCTAssertTrue(element(UnusedFoldID.id).exists)
    }

    func testSendsFoldUnusedBuses() {
        launchAndOpen("Kick", tab: "Sends")
        XCTAssertTrue(element("/ch/01/mix/01/level").appears(within: 2))
        XCTAssertFalse(element("/ch/01/mix/09/level").exists)
        let fold = element(UnusedFoldID.id)
        XCTAssertEqual(fold.label, "Show unused")
        fold.tap()
        XCTAssertTrue(element("/ch/01/mix/09/level").appears(within: 2))
        fold.tap()
    }

    /// The class shares one app: a fold a previous test left open is closed first.
    private func foldClosed() -> XCUIElement {
        let fold = element(UnusedFoldID.id)
        XCTAssertTrue(fold.appears(within: 3))
        if fold.label == "Hide unused" { fold.tap() }
        XCTAssertTrue(eventually(within: 2) { fold.label == "Show unused" })
        return fold
    }
}

private enum UnusedFoldID {
    static let id = "unused-fold"
}

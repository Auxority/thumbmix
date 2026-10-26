import XCTest

final class ShareLogUITests: DeskUITestCase {
    /// A shake, mid-show, offers this run's log as a file to attach to a GitHub issue; the desk stays connected.
    func testAShakeSharesThisRunsLog() {
        launch()
        // XCUITest can't shake a simulator; Debug builds take this URL instead.
        XCUIDevice.shared.system.open(URL(string: "thumbmix-test://shake")!)
        let alert = app.alerts["Share this run's log?"]
        XCTAssertTrue(alert.appears(within: 5), "step 1: a shake asks")
        saveScreenshot("share-log-alert")

        alert.buttons["Share"].tap()
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Thumbmix log'"))
            .firstMatch
        XCTAssertTrue(file.appears(within: 15), "step 2: the share sheet offers the log file")
        saveScreenshot("share-log-sheet")

        // The next test, maybe of another class, gets this app as it's left.
        app.buttons["header.closeButton"].tap()
        XCTAssertTrue(eventually(within: 5) { !file.exists }, "step 3: Close leaves the sheet")
    }
}

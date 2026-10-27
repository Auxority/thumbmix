import XCTest

/// A UI test with the app connected to the test's own fake desk.
@MainActor
class DeskUITestCase: XCTestCase {
    var app: XCUIApplication!
    /// Started on first use, so a test can change the desk before the app launches.
    lazy var desk: TestDesk! = TestDesk.start(for: self)

    /// One launch per simulator, across test classes: a launch is ~6.5 s (mostly XCTest attaching to the app), so
    /// later tests send the running app to their own fresh desk instead. It relaunches when the arguments change.
    nonisolated(unsafe) fileprivate static var running: (app: XCUIApplication, arguments: [String])?

    override class func setUp() {
        super.setUp()
        _ = otherLaunchObserver
    }

    override func setUp() {
        continueAfterFailure = false
    }

    /// A failed test may leave a sheet or alert open: the next test, maybe of another class, launches afresh.
    override func tearDown() {
        // Not `hasSucceeded`: it reads false until the run has stopped, after tearDown.
        if let testRun, testRun.totalFailureCount > 0 { Self.running = nil }
    }

    /// Classes like `ConnectUITests` launch the app with their own arguments, and the app they leave running looks
    /// the same as ours: a test of theirs starting drops ours. Kept here, so it lives as long as the test run.
    nonisolated private static let otherLaunchObserver: OtherLaunchObserver = {
        let observer = OtherLaunchObserver()
        XCTestObservationCenter.shared.addTestObserver(observer)
        return observer
    }()

    /// Every list shows its unused strips, as these tests were written for; `UnusedFoldUITests` starts them folded.
    /// Read only at a launch: a class that opens or closes a fold must launch with other arguments, as that one does.
    class var showsUnusedStrips: Bool { true }

    /// Launched per test rather than in setUp: the setUp override is nonisolated, XCUIApplication is main-actor.
    func launch(_ extraArguments: [String] = []) {
        let arguments = extraArguments + ["-showsUnusedStrips", Self.showsUnusedStrips ? "YES" : "NO"]
        if let running = Self.running, running.arguments == arguments, running.app.state == .runningForeground {
            app = running.app
            // Through the system: XCUIApplication.open relaunches the app and attaches again, the cost this avoids.
            XCUIDevice.shared.system.open(URL(string: "thumbmix-test://connect?port=\(desk.port)")!)
            XCTAssertTrue(eventually(within: 5) { desk.heardFromApp }, "the app didn't switch to this test's desk")
        } else {
            app = XCUIApplication()
            app.launchArguments =
                desk.connect + arguments + fixedLocale + (arguments.contains("-tips") ? [] : quietTips)
                + ["-disableAnimations", "YES"]
            app.launch()
            Self.running = (app, arguments)
        }
        // A new desk's rows show once its sync is done; a list held through a lost contact shows them disabled until
        // then, where a tap does nothing. With several simulators sharing the Mac, the sync can outlast the first tap.
        let kick = app.buttons["Kick"]
        XCTAssertTrue(eventually(within: 15) { kick.exists && kick.isEnabled })
    }

    /// Waits for the Mix tab's pill: only a strip screen has it, the overview's pills name groups.
    func open(_ name: String) {
        app.buttons[name].tap()
        XCTAssertTrue(app.buttons["Mix"].appears(within: 3))
    }

    /// Launches, then opens one strip as the tests do by hand: through its group pill (Buses, DCA, FX) when it isn't on the
    /// first page, and on `tab` when the test starts there.
    func launchAndOpen(_ name: String, group: String? = nil, tab: String? = nil) {
        launch()
        if let group { app.buttons[group].tap() }
        open(name)
        if let tab { app.buttons[tab].tap() }
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// A tab's last row (Reset) can start below the SE's bottom edge: drag the tab up from a visible `handle`, never from
    /// the hidden row, which would land under the tab bar.
    func scrollUntilHittable(_ target: XCUIElement, from handle: XCUIElement) {
        XCTAssertTrue(target.appears(within: 2))
        guard !target.isHittable else { return }
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -300)))
        XCTAssertTrue(eventually(within: 2) { target.isHittable }, "\(target) on screen after a scroll")
    }

    /// A strip's solo switch on the desk, numbered in the desk's strip order (inputs 1-32, …, buses 49-64).
    func soloAddress(_ number: Int) -> String { String(format: "/-stat/solosw/%02d", number) }

    /// Every solo switch in `numbers` reads `value` on the desk.
    func solos(_ numbers: ClosedRange<Int>, are value: Int32) -> Bool {
        numbers.allSatisfy { desk.value(soloAddress($0)) == .int(value) }
    }

    static let exclusiveSolo = "/config/solo/exclusive"
}

private final class OtherLaunchObserver: NSObject, XCTestObservation, Sendable {
    func testCaseWillStart(_ testCase: XCTestCase) {
        if !(testCase is DeskUITestCase) { DeskUITestCase.running = nil }
    }
}

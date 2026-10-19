import XCTest

/// A UI test with the app connected to the test's own fake desk.
@MainActor
class DeskUITestCase: XCTestCase {
    var app: XCUIApplication!
    /// Started on first use, so a test can change the desk before the app launches.
    lazy var desk: TestDesk! = TestDesk.start(for: self)

    /// One launch per test class: a launch is ~6.5 of a test's ~9.5 s (mostly XCTest attaching to the app), so
    /// later tests send the running app to their own fresh desk instead. Other classes launch the app themselves.
    nonisolated(unsafe) private static var running: (app: XCUIApplication, arguments: [String])?

    override func setUp() {
        continueAfterFailure = false
    }

    override class func tearDown() {
        running = nil
        super.tearDown()
    }

    /// Every list shows its unused strips, as these tests were written for; `UnusedFoldUITests` starts them folded.
    /// Set at each launch, so a fold opened in another class doesn't leak in.
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
        // Names show while the sync still runs and the rows are disabled; a tap then does nothing. With several
        // simulators sharing the Mac, the sync can outlast the first tap.
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

    /// A strip's solo switch on the desk, numbered in the desk's strip order (inputs 1-32, …, buses 49-64).
    func soloAddress(_ number: Int) -> String { String(format: "/-stat/solosw/%02d", number) }

    /// Every solo switch in `numbers` reads `value` on the desk.
    func solos(_ numbers: ClosedRange<Int>, are value: Int32) -> Bool {
        numbers.allSatisfy { desk.value(soloAddress($0)) == .int(value) }
    }

    static let exclusiveSolo = "/config/solo/exclusive"
}

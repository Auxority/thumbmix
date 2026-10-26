import XCTest

@MainActor
final class ConnectUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// A fresh start stays on the Connect screen; the console used last is one tap away, marked Online once it
    /// answered the scan.
    func testAFreshStartOffersTheLastConsole() {
        guard let desk = TestDesk.start(for: self) else { return }
        let app = launch(desk.reachable, remembering: ["Fake M32"])

        let connect = app.buttons["Connect"]
        XCTAssertTrue(app.staticTexts["Online"].appears(within: 8), "the remembered console answered the scan")
        XCTAssertFalse(app.buttons["Kick"].exists, "a fresh start doesn't connect by itself")
        saveScreenshot("connect-last-used")
        assertLabelContrasts(connect)

        connect.tap()
        XCTAssertTrue(app.buttons["Kick"].appears(within: 15))
    }

    /// A desk switched on after the Connect screen opened misses the first scan; a later one finds it, no tap needed.
    func testADeskThatBootsLaterTurnsOnline() {
        guard let desk = TestDesk.start(for: self) else { return }
        desk.goSilent()
        let app = launch(desk.reachable, remembering: ["Fake M32"])
        XCTAssertTrue(app.staticTexts["Not found"].appears(within: 8), "step 1: the booting desk missed the first scan")

        desk.answerAgain()
        XCTAssertTrue(app.staticTexts["Online"].appears(within: 8), "step 2: a later scan found it")
    }

    /// The decimal keypad shows the region's separator, so in the Netherlands it only types commas.
    func testCommasFromADutchKeypadBecomeDots() {
        guard let desk = TestDesk.start(for: self) else { return }
        let app = launch(desk.reachable + ["-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"], locale: [])

        let field = openAddressAlert(app)
        saveScreenshot("connect-enter-ip")
        clear(field)
        // One key at a time: XCUITest's fast typing dropped keys in this field.
        for key in "127,0,0,1" { field.typeText(String(key)) }
        XCTAssertEqual(field.value as? String, "127.0.0.1", "each comma shows as the dot it means")
        app.alerts.buttons["Connect"].tap()

        XCTAssertTrue(app.buttons["Kick"].appears(within: 15))
    }

    /// Text that isn't an address reopens the alert saying why, text kept to fix. An address that answers as an X32 is
    /// refused: Thumbmix speaks the M32's protocol.
    func testATypedX32IsRefused() {
        guard let desk = TestDesk.start(for: self, model: "X32") else { return }
        let app = launch(desk.reachable)

        var field = openAddressAlert(app)
        clear(field)
        field.typeText("192.168.1")
        app.alerts.buttons["Connect"].tap()
        XCTAssertTrue(app.alerts["Not an IP address"].appears(within: 3), "the alert reopens saying why")
        field = app.alerts.textFields.firstMatch
        XCTAssertEqual(field.value as? String, "192.168.1", "the text stays to fix")

        clear(field)
        field.typeText("127.0.0.1")
        app.alerts.buttons["Connect"].tap()
        XCTAssertTrue(app.alerts["That's an X32"].appears(within: 10))
    }

    /// iOS hides a denied Local Network permission as silence, so the alert asks about both causes. The console used
    /// last is the card, which has no swipe; one in the list can be forgotten.
    func testANoReplyNamesTheConsole() {
        // Nothing listens on port 9 of this Mac.
        let app = launch(["-consolePort", "9"], remembering: ["Fake M32", "Zaal 2"])

        XCTAssertTrue(app.staticTexts["Not found"].appears(within: 8))
        app.buttons["Connect"].tap()
        let alert = app.alerts["Can't reach Fake M32"]
        XCTAssertTrue(alert.appears(within: 10))
        XCTAssertTrue(alert.buttons["Settings"].exists)
        saveScreenshot("connect-no-reply")
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["Enter IP"].appears(within: 3))

        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Zaal 2'")).firstMatch
        XCTAssertTrue(row.appears(within: 5))
        XCTAssertTrue(row.isHittable)
        row.swipeLeft()
        app.buttons["Forget"].tap()
        XCTAssertTrue(eventually(within: 3) { !row.exists }, "the row is forgotten")
        XCTAssertTrue(app.staticTexts["Fake M32"].exists, "the card stays")
    }

    /// `remembering`: consoles on this Mac's loopback, the first one used last. None by default, so consoles
    /// another test remembered on this simulator don't show.
    private func launch(
        _ arguments: [String] = [], remembering names: [String] = [], locale: [String] = fixedLocale
    ) -> XCUIApplication {
        let entries = names.map { "{host=\"127.0.0.1\";name=\"\($0)\";model=M32;}" }
        let app = XCUIApplication()
        app.launchArguments = ["-knownConsoles", "(" + entries.joined(separator: ",") + ")"] + arguments + locale + quietTips
        app.launch()
        return app
    }

    private func openAddressAlert(_ app: XCUIApplication) -> XCUIElement {
        let enterIP = app.buttons["Enter IP"]
        XCTAssertTrue(enterIP.appears(within: 5))
        enterIP.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.appears(within: 3))
        return field
    }

    /// The field starts with this Mac's network, which these tests don't use.
    private func clear(_ field: XCUIElement) {
        let text = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
    }
}

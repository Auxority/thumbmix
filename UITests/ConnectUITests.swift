import XCTest

@MainActor
final class ConnectUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The decimal keypad shows the region's separator, so in the Netherlands it only types commas.
    func testCommasFromADutchKeypadBecomeDots() {
        let app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", "", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launch()

        let field = app.textFields["console-ip"]
        XCTAssertTrue(field.appears(within: 5))
        field.tap()
        field.typeText("192,168,1,50")
        XCTAssertEqual(field.value as? String, "192.168.1.50")
        XCTAssertTrue(app.buttons["Connect"].isEnabled)
    }

    func testRejectsInvalidAddress() {
        let app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", ""] + fixedLocale
        app.launch()

        let field = app.textFields["console-ip"]
        XCTAssertTrue(field.appears(within: 5))
        field.tap()
        field.typeText("192.168.1")
        XCTAssertFalse(app.buttons["Connect"].isEnabled)
        saveScreenshot("connect-disabled")
        assertLabelContrasts(app.buttons["Connect"])
    }

    /// The app tint is white, so the prominent button drew its default white label on a white fill.
    func testEnabledConnectLabelIsVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["-lastConsoleHost", ""] + fixedLocale
        app.launch()

        let field = app.textFields["console-ip"]
        XCTAssertTrue(field.appears(within: 5))
        field.tap()
        field.typeText("10.0.0.1")
        let connect = app.buttons["Connect"]
        XCTAssertTrue(connect.isEnabled)
        saveScreenshot("connect-enabled")
        assertLabelContrasts(connect)
    }

    func testConnectsToFakeAndSyncs() {
        guard let desk = TestDesk.start(for: self) else { return }
        let app = XCUIApplication()
        app.launchArguments = desk.connect + fixedLocale
        app.launch()

        XCTAssertTrue(app.buttons["Kick"].appears(within: 15))
    }
}

/// A readable label differs clearly from its button's fill, taken as the median brightness of the button's central half.
/// The central crop keeps the page showing through a capsule's rounded corners out of the count.
@MainActor
private func assertLabelContrasts(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let brightness = brightnessValues(inMiddleOf: element.screenshot().image).sorted()
    guard !brightness.isEmpty else { return XCTFail("could not read the button's pixels", file: file, line: line) }
    let fill = brightness[brightness.count / 2]
    let labelShare = Double(brightness.count { abs($0 - fill) > 48 }) / Double(brightness.count)
    XCTAssertGreaterThan(labelShare, 0.01, "the label blends into its fill", file: file, line: line)
}

/// Mean of R, G and B (0–255) for each pixel in the central half of the image.
private func brightnessValues(inMiddleOf image: UIImage) -> [Int] {
    guard let full = image.cgImage else { return [] }
    let crop = CGRect(x: full.width / 4, y: full.height / 4, width: full.width / 2, height: full.height / 2)
    guard let middle = full.cropping(to: crop) else { return [] }
    let width = middle.width
    let height = middle.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = pixels.withUnsafeMutableBytes { buffer in
        guard
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.draw(middle, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { return [] }
    return stride(from: 0, to: pixels.count, by: 4).map { offset in
        (Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])) / 3
    }
}

import XCTest

/// Saves the screen for layout review when the run sets SCREENSHOT_DIR (via TEST_RUNNER_SCREENSHOT_DIR); a no-op otherwise.
@MainActor
func saveScreenshot(_ name: String) {
    guard let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
    let file = URL(fileURLWithPath: directory).appendingPathComponent(name + ".png")
    do {
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: file)
    } catch {
        XCTFail("could not save screenshot \(name): \(error)")
    }
}

/// The brightness (0-1) of the screen's pixel at `point`, from a screenshot taken now.
@MainActor
func screenBrightness(at point: CGPoint) -> CGFloat {
    let image = XCUIScreen.main.screenshot().image
    guard let cgImage = image.cgImage else { return 0 }
    let scale = CGFloat(cgImage.width) / image.size.width
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    context?.draw(
        cgImage,
        in: CGRect(
            x: -point.x * scale, y: point.y * scale - CGFloat(cgImage.height),
            width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    return CGFloat(Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2])) / (3 * 255)
}

/// Assertions compare English, dot-decimal text, so the app runs in en_US whatever the Mac's region is.
let fixedLocale = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

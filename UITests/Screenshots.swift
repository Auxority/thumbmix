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

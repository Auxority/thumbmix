import XCTest

/// A preset `.json` shared to Thumbmix from AirDrop, Mail or Messages. XCUITest can't share a file to the app, so
/// `thumbmix-test://open?path=…` hands it the file through the same `AppModel.open` the system calls. The Info.plist
/// document type that makes iOS offer Thumbmix is not reached here; the wiring from the file to the notice is.
@MainActor
final class OpenPresetFileUITests: DeskUITestCase {
    private let preset = """
        {"format": "thumbmix-preset", "version": 1, "name": "Shared kick", "matchWords": ["kick"],
         "stripKind": "input", "mix": {"mix/pan": 0}}
        """

    /// Opened with the presets page showing: the notice says where it went, and the page lists it. Another JSON is
    /// refused with its reason.
    func testASharedPresetLandsOnThisIPhoneAndOtherJSONIsRefused() throws {
        launch(["-isolatedPresets", "YES"])
        open("Kick")
        app.buttons["edit-strip"].tap()
        element("presets-row").tap()
        XCTAssertTrue(element("presets-save").appears(within: 3))
        XCTAssertFalse(element("preset-row-Shared kick").exists)

        share(try write(preset, as: "shared-kick.json"))
        let notice = app.alerts["Presets"]
        XCTAssertTrue(notice.appears(within: 5), "the alert shows over the edit sheet")
        XCTAssertTrue(notice.staticTexts.element(boundBy: 1).label.contains("Shared kick"))
        XCTAssertTrue(notice.staticTexts.element(boundBy: 1).label.contains("On this iPhone"))
        saveScreenshot("preset-file-added")
        notice.buttons["OK"].tap()
        XCTAssertTrue(element("preset-row-Shared kick").appears(within: 3), "listed on the presets page")

        share(try write(#"{"hello": "world"}"#, as: "other.json"))
        XCTAssertTrue(notice.appears(within: 5))
        XCTAssertTrue(notice.staticTexts["other.json was not added: This is not a Thumbmix preset file."].exists)
        saveScreenshot("preset-file-refused")
        notice.buttons["OK"].tap()
    }

    private func write(_ text: String, as name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return url
    }

    private func share(_ file: URL) {
        var components = URLComponents(string: "thumbmix-test://open")!
        components.queryItems = [URLQueryItem(name: "path", value: file.path)]
        XCUIDevice.shared.system.open(components.url!)
    }
}

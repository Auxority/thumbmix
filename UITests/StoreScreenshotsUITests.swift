import ThumbmixCore
import XCTest

/// The screenshots SideStore shows (user's pick, 2026-10-31): Overview, EQ, Comp, Sends, DCA members, on a believable
/// band mix. Runs only from `scripts/store-screenshots.sh`, which sets STORE_SCREENSHOT_DIR; the suite skips it.
@MainActor
final class StoreScreenshotsUITests: DeskUITestCase {
    private let vox = StripID(.input, 13)

    func testStoreScreenshots() throws {
        guard let path = ProcessInfo.processInfo.environment["STORE_SCREENSHOT_DIR"] else {
            throw XCTSkip("only scripts/store-screenshots.sh takes these")
        }
        let directory = URL(fileURLWithPath: path)
        setUpTheMix()
        launch()
        save("1-overview", in: directory)

        open("Vox 1")
        app.buttons["EQ"].tap()
        XCTAssertTrue(eventually(within: 5) { self.desk.value(RTA.source) == .int(14) }, "the spectrum follows Vox 1")
        // The presence boost: band 1 would do, but a band with its gain and Q shows what the rows do.
        app.buttons["3"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        save("2-eq", in: directory)

        app.buttons["Comp"].tap()
        XCTAssertTrue(element(vox.prefix + "/dyn/thr").appears(within: 2))
        Thread.sleep(forTimeInterval: 1.5)
        save("3-comp", in: directory)

        app.buttons["Sends"].tap()
        XCTAssertTrue(element(vox.prefix + "/mix/01/level").appears(within: 2))
        save("4-sends", in: directory)

        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["DCA"].tap()
        open("Drums")
        app.buttons["Members"].tap()
        XCTAssertTrue(element("assign-/ch/02").appears(within: 3))
        save("5-dca-members", in: directory)
    }

    /// The desk as a band's soundcheck leaves it, set before the launch so the first sync reads it.
    private func setUpTheMix() {
        let faders: [(Int, Double)] = [
            (1, -2), (2, -3.5), (3, -8), (4, -5), (5, -5.5), (6, -7), (7, -7), (8, -1), (9, -4.5), (10, -4.5),
            (11, -6), (12, -6), (13, 1), (14, -3),
        ]
        for (channel, decibels) in faders { set(Catalog.fader(StripID(.input, channel)), decibels) }
        set(Catalog.on(StripID(.input, 5)), 0)
        setUpVox()
    }

    /// Vox 1: a low cut, a dip in the mud, presence and air; 3:1 compression that works; sends to four wedges.
    private func setUpVox() {
        if let lowCut = Catalog.lowCut(vox) {
            set(lowCut.on, 1)
            set(lowCut.frequency, 100)
        }
        set(Catalog.eqOn(vox), 1)
        let bands: [(EQFilterType, Double, Double)] = [
            (.parametric, 300, -3), (.parametric, 1_200, -1.5), (.parametric, 3_200, 3), (.highShelf, 10_000, 2),
        ]
        for (band, (type, frequency, gain)) in bands.enumerated() {
            let specs = Catalog.eqBand(vox, band + 1)
            set(specs.type, Double(EQFilterType.ofInputs.firstIndex(of: type) ?? 0))
            set(specs.frequency, frequency)
            set(specs.gain, gain)
        }
        let dynamics = Catalog.dynamics(vox)
        set(dynamics.on, 1)
        set(dynamics.threshold, -24)
        set(dynamics.ratio, Double(Catalog.ratios.firstIndex(of: "3.0") ?? 0))
        set(dynamics.makeup, 4)
        for (bus, decibels) in [(1, -2.0), (2, -6), (3, -4), (4, -9)] {
            set(Catalog.sendLevel(from: vox, to: StripID(.bus, bus)), decibels)
            set(Catalog.sendOn(from: vox, to: StripID(.bus, bus)), 1)
        }
    }

    private func set(_ spec: ParamSpec, _ value: Double) {
        switch spec.scale.argument(fromNormalized: spec.scale.normalized(forValue: value)) {
        case .int(let int): desk.change(spec.address, int)
        case .float(let float): desk.change(spec.address, float: float)
        default: XCTFail("\(spec.address) takes neither an int nor a float")
        }
    }

    private func save(_ name: String, in directory: URL) {
        let file = directory.appendingPathComponent(name + ".png")
        XCTAssertNoThrow(try XCUIScreen.main.screenshot().pngRepresentation.write(to: file), name)
    }
}

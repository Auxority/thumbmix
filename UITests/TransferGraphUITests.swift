import XCTest

@MainActor
final class TransferGraphUITests: DeskUITestCase {
    /// The dashed 1:1 line over the fork stays put while the threshold moves (2026-10-17): the dashes used to start
    /// where the fork starts, so each threshold step slid them along the line.
    func testDashesStayPutWhileTheThresholdMoves() {
        // No makeup, so the fork starts near the threshold instead of at the floor.
        desk.change("/ch/01/dyn/mgain", float: 0)
        launchAndOpen("Kick", tab: "Comp")
        let graph = element("comp-graph")
        let threshold = element("/ch/01/dyn/thr")
        XCTAssertTrue(eventually(within: 2) { threshold.value as? String == "−30.0 dB" }, "the tab was read")
        // Until the desk sent every value the curve needs, the card shows only a dim 1:1 line, not the grey dashes.
        var before: [UInt8] = []
        XCTAssertTrue(
            eventually(within: 2) {
                before = dashes(in: graph)
                return before.contains(153)
            }, "no dashes")

        desk.change("/ch/01/dyn/thr", float: 59.0 / 120)  // -30.5 dB: one desk step
        XCTAssertTrue(eventually(within: 2) { threshold.value as? String == "−30.5 dB" })
        XCTAssertTrue(dashes(in: graph) == before, "the dashes moved with the threshold")
        saveScreenshot("comp-fork-no-makeup")
    }

    /// The 1:1 line between −8 and −3 dB in: far above the threshold, so the compressed curve (and the level dot on
    /// it) runs well below, and the reduction bar sits at the bottom.
    private func dashes(in graph: XCUIElement) -> [UInt8] {
        let fraction = { (decibels: Double) in (decibels + 80) / 80 }
        let region = CGRect(
            x: fraction(-8), y: 1 - fraction(-3), width: fraction(-3) - fraction(-8), height: fraction(-3) - fraction(-8))
        return rgbaBytes(of: graph.screenshot().image, in: region)
    }
}

import Testing

@testable import ThumbmixCore

/// The EQ graph's number tags (2026-10-22, mock T4 in `notes/mocks/2026-10-22-eq-graph/eq-graph-round4.html`).
struct EQTagLayoutTests {
    private let layout = EQTagLayout(tagSize: 22)
    private let width = 343.0
    private let height = 190.0

    private func tags(_ dots: [Int: EQTagLayout.Spot], pinned: EQTagLayout.Pin? = nil) -> [Int: EQTagLayout.Spot] {
        layout.tags(for: dots, width: width, height: height, pinned: pinned)
    }

    private func spot(_ x: Double, _ y: Double) -> EQTagLayout.Spot { EQTagLayout.Spot(x: x, y: y) }

    @Test func aLoneTagSitsStraightAboveItsDot() {
        #expect(tags([2: spot(150, 120)]) == [2: spot(150, 120 - layout.lift)])
    }

    @Test func nearTheTopEdgeTheTagHangsBelow() {
        #expect(tags([3: spot(200, 15)]) == [3: spot(200, 15 + layout.lift)])
    }

    @Test func tagsFarApartStayPut() {
        #expect(tags([1: spot(60, 100), 3: spot(250, 100)]) == [1: spot(60, 100 - layout.lift), 3: spot(250, 100 - layout.lift)])
    }

    /// Dots on one spot: a row centred on them, in band order, one tag and a gap apart.
    @Test func dotsOnOneSpotGetARowOfTags() {
        let row = tags([2: spot(150, 120), 3: spot(150, 120)])
        let step = layout.tagSize + layout.gap
        #expect(row[2] == spot(150 - step / 2, 120 - layout.lift))
        #expect(row[3] == spot(150 + step / 2, 120 - layout.lift))
    }

    /// Frequency order, so stems never cross; the row sits above the highest dot.
    @Test func aCrowdLinesUpInFrequencyOrder() {
        let row = tags([4: spot(150, 110), 2: spot(160, 130), 3: spot(170, 120)])
        let xs = [4, 2, 3].map { row[$0]!.x }
        #expect(xs == xs.sorted())
        #expect(Set([4, 2, 3].map { row[$0]!.y }) == [110 - layout.lift])
        #expect(abs((xs[0] + xs[2]) / 2 - 160) < 1e-9, "centred on the dots")
        #expect(abs(xs[1] - xs[0] - (layout.tagSize + layout.gap)) < 1e-9)
    }

    @Test func aRowAtTheLeftEdgeSlidesInward() {
        let row = tags([0: spot(1, 140), 1: spot(4, 140), 2: spot(8, 140)])
        #expect(row[0]!.x - layout.tagSize / 2 >= 2)
    }

    @Test func aRowAtTheRightEdgeSlidesInward() {
        let row = tags([3: spot(width - 4, 140), 4: spot(width - 1, 140)])
        #expect(row[4]!.x + layout.tagSize / 2 <= width - 2)
    }

    /// While dragged, a band's tag keeps its place beside its dot from touch-down, so it never slides out from under
    /// the finger; the others make room (Q6 B).
    @Test func aDraggedTagKeepsItsPlaceBesideItsDot() {
        let before = tags([2: spot(150, 120), 3: spot(150, 120)])
        let pin = EQTagLayout.Pin(band: 3, offset: before[3]!.x - 150)
        #expect(tags([2: spot(150, 120), 3: spot(150, 120)], pinned: pin) == before, "touch-down moves nothing")
        let dragged = tags([2: spot(150, 120), 3: spot(140, 120)], pinned: pin)
        #expect(dragged[3]!.x == 140 + pin.offset)
        #expect(dragged[2]!.x == dragged[3]!.x + layout.tagSize + layout.gap, "2, now higher, made room on the right")
    }

    @Test func tagsAtDifferentHeightsDontJoin() {
        let row = tags([1: spot(150, 60), 2: spot(152, 150)])
        #expect(row == [1: spot(150, 60 - layout.lift), 2: spot(152, 150 - layout.lift)])
    }
}

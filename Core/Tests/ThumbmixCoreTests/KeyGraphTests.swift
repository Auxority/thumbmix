import Testing

@testable import ThumbmixCore

/// What the key graph draws (2026-10-20): the key filter's shape over the RTA of what the key listens to.
@MainActor
struct KeyGraphTests {
    private let ch1 = StripID(.input, 1)
    private let ch2 = StripID(.input, 2)
    private let ch10 = StripID(.input, 10)
    private let mtx1 = StripID(.matrix, 1)

    private func mirror(_ changes: [String: OSCArgument], forgetting forgotten: [String] = []) -> ConsoleMirror {
        var state = DemoState.values().merging(changes) { $1 }
        for address in forgotten { state[address] = nil }
        return ConsoleMirror.preview(state)
    }

    private func filter(_ type: Int, _ hertz: Double) -> KeyFilterState { KeyFilterState(typeIndex: type, frequency: hertz) }

    @Test func cutsAreThreeDecibelsDownAtTheirFrequency() {
        for type in 0...3 { #expect(abs(filter(type, 150).decibels(at: 150) + 3.01) < 0.01, "type \(type)") }
    }

    @Test func aTwelveDecibelCutFallsTwelveAnOctaveOut() {
        #expect(abs(filter(1, 150).decibels(at: 75) + 12.3) < 0.1, "LC12 an octave below")
        #expect(abs(filter(3, 150).decibels(at: 300) + 12.3) < 0.1, "HC12 an octave above")
        #expect(abs(filter(1, 150).decibels(at: 1_000)) < 0.1, "a low cut passes the highs")
    }

    @Test func aBandPassPeaksAtZeroAndNarrowsWithQ() {
        let wide = filter(4, 1_000)
        let narrow = filter(8, 1_000)
        #expect(abs(wide.decibels(at: 1_000)) < 0.001)
        #expect(abs(narrow.decibels(at: 1_000)) < 0.001)
        #expect(narrow.decibels(at: 2_000) < wide.decibels(at: 2_000) - 10)
    }

    /// The safety rule: no shape the desk didn't send.
    @Test func anUnreadFilterHasNoShape() {
        let key = Catalog.gateKey(ch1)
        #expect(mirror([:]).keyFilter(key) != nil)
        #expect(mirror([:], forgetting: ["/ch/01/gate/filter/type"]).keyFilter(key) == nil)
        #expect(mirror([:], forgetting: ["/ch/01/gate/filter/f"]).keyFilter(key) == nil)
        #expect(mirror([:], forgetting: ["/ch/01/gate/filter/on"]).isKeyFilterOn(key) == nil)
    }

    @Test func theGateListensBeforeTheSourcesEQ() throws {
        let other = try #require(mirror(["/ch/01/gate/keysrc": .int(2)]).keyRTA(ch1, owner: .gate))
        #expect(other.strip == ch2)
        #expect(!other.afterEQ)
        let own = try #require(mirror(["/ch/01/gate/keysrc": .int(0)]).keyRTA(ch1, owner: .gate))
        #expect(own.strip == ch1)
        #expect(!own.afterEQ, "the gate sits before the EQ")
    }

    @Test func selfOnTheCompFollowsCompPosition() throws {
        let post = try #require(mirror(["/ch/01/dyn/keysrc": .int(0), "/ch/01/dyn/pos": .int(1)]).keyRTA(ch1, owner: .comp))
        #expect(post.strip == ch1)
        #expect(post.afterEQ)
        let pre = try #require(mirror(["/ch/01/dyn/keysrc": .int(0), "/ch/01/dyn/pos": .int(0)]).keyRTA(ch1, owner: .comp))
        #expect(!pre.afterEQ)
        let other = try #require(mirror(["/ch/01/dyn/keysrc": .int(2), "/ch/01/dyn/pos": .int(1)]).keyRTA(ch1, owner: .comp))
        #expect(other.strip == ch2)
        #expect(!other.afterEQ, "another strip: before its EQ")
    }

    @Test func selfListensToTheSideShown() {
        let changes: [String: OSCArgument] = ["/ch/10/dyn/keysrc": .int(0), "/ch/10/dyn/pos": .int(1)]
        #expect(mirror(changes).keyRTA(ch10, owner: .comp)?.strip == ch10)
    }

    @Test func aCompWithoutASourceListensToItself() throws {
        let rta = try #require(mirror(["/mtx/01/dyn/pos": .int(1)]).keyRTA(mtx1, owner: .comp))
        #expect(rta.strip == mtx1)
        #expect(rta.afterEQ)
    }

    @Test func anUnreadSourceBorrowsNothing() {
        #expect(mirror([:], forgetting: ["/ch/01/dyn/keysrc"]).keyRTA(ch1, owner: .comp) == nil)
        #expect(mirror(["/ch/01/dyn/keysrc": .int(0)], forgetting: ["/ch/01/dyn/pos"]).keyRTA(ch1, owner: .comp) == nil)
    }

    @Test func theFilteredSpectrumDropsWhereTheFilterCuts() {
        let flat = [Float](repeating: -20, count: RTA.bandCount)
        let filtered = RTA.filtered(flat) { $0 < 100 ? -12 : 0 }
        #expect(filtered[0] == -32, "20 Hz, cut")
        #expect(filtered[RTA.bandCount - 1] == -20, "18.7 kHz, passed")
        #expect(RTA.filtered([-2]) { _ in 10 } == [0], "never above full scale")
    }
}

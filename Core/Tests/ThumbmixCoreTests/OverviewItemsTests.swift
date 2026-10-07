import Testing

@testable import ThumbmixCore

/// The overview shows a linked pair as one row while its faders move together, and as two half-striped rows when
/// the desk's fader link is off: one fader can't stand for two.
@MainActor
struct OverviewItemsTests {
    private let mirror = ConsoleMirror.preview()
    private let inputs = StripID.all(.input)

    @Test func aLinkedPairIsOneRow() {
        let items = mirror.overviewItems(inputs, showUnused: false)
        #expect(items.contains(.pair(StripID(.input, 9))))
        #expect(!items.contains { $0.opens == StripID(.input, 10) && $0 != .pair(StripID(.input, 9)) })
        #expect(items.contains(.strip(StripID(.input, 8), .full)))
    }

    @Test func separateFadersSplitThePairIntoHalfStripedRows() {
        mirror.apply(OSCMessage(LinkSection.faderMute.preferenceAddress, [.int(0)]))
        let items = mirror.overviewItems(inputs, showUnused: false)
        #expect(items.contains(.strip(StripID(.input, 9), .top)))
        #expect(items.contains(.strip(StripID(.input, 10), .bottom)))
        #expect(!items.contains(.pair(StripID(.input, 9))))
    }

    /// Either row of a pair opens the pair's screen, which belongs to the odd side.
    @Test func everyRowOfAPairOpensTheOddSide() {
        mirror.apply(OSCMessage(LinkSection.faderMute.preferenceAddress, [.int(0)]))
        #expect(OverviewItem.strip(StripID(.input, 10), .bottom).opens == StripID(.input, 9))
        #expect(OverviewItem.pair(StripID(.input, 9)).opens == StripID(.input, 9))
        #expect(OverviewItem.strip(StripID(.input, 8), .full).opens == StripID(.input, 8))
    }

    @Test func pairShowsWhenEitherSideIsUsed() {
        let odd = StripID(.input, 21)
        mirror.apply(OSCMessage("/config/chlink/21-22", [.int(1)]))
        #expect(!mirror.overviewItems(inputs, showUnused: false).contains(.pair(odd)), "both sides unused")
        mirror.apply(OSCMessage(StripID(.input, 22).name, [.string("Synth R")]))
        #expect(mirror.overviewItems(inputs, showUnused: false).contains(.pair(odd)))
    }
}

import Testing

@testable import ThumbmixCore

/// A Fed by row's › opens the send sheet, as on Sends (2026-10-14); the sheet's title links both strips.
struct FedBySendSheetTests {
    private let kick = StripID(.input, 1)

    /// The mains are numbered 1, so without a guard Ch 1 → Main LR would name bus 1's tap (`/ch/01/mix/01/type`).
    @Test func theMainsHaveNoSendSettings() {
        for main in [StripID(.mainStereo), StripID(.mainMono)] {
            #expect(Catalog.sendTap(from: kick, to: main) == nil)
            #expect(Catalog.sendPan(from: kick, to: main) == nil)
            #expect(Catalog.sendPanFollow(from: kick, to: main) == nil)
        }
        #expect(Catalog.sendTap(from: StripID(.bus, 1), to: StripID(.matrix, 1))?.address == "/bus/01/mix/01/type")
        #expect(Catalog.sendTap(from: StripID(.mainStereo), to: StripID(.matrix, 3))?.address == "/main/st/mix/03/type")
    }

    /// A send's source opens on Sends, where the send is a row; its mix on Fed by, as before. The strip already on
    /// screen just closes the sheet.
    @Test func aTitleLinkOpensTheStripOnTheTabThatShowsTheSend() {
        let mon1 = StripID(.bus, 1)
        #expect(ChannelTab.opened(mon1, from: kick) == .fedBy)
        #expect(ChannelTab.opened(kick, from: mon1) == .sends)
        #expect(ChannelTab.opened(mon1, from: StripID(.matrix, 1)) == .sends, "a bus feeding a matrix")
        #expect(ChannelTab.opened(StripID(.matrix, 1), from: mon1) == .fedBy)
        #expect(ChannelTab.opened(StripID(.mainStereo), from: StripID(.matrix, 1)) == .sends)
        #expect(ChannelTab.opened(mon1, from: mon1) == nil)
        #expect(ChannelTab.opened(kick, from: kick) == nil)
    }
}

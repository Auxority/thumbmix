import FakeM32
import Testing

@testable import ThumbmixCore

/// "To Main LR" is `mix/st` on inputs, aux ins, FX returns and buses (doc p.25-31); matrices, the mains and DCAs
/// have no such switch.
@MainActor
struct MainLRTests {
    @Test func onlyStripsThatFeedTheMainsHaveTheSwitch() {
        #expect(StripID(.input, 1).mainLR == "/ch/01/mix/st")
        #expect(StripID(.auxIn, 2).mainLR == "/auxin/02/mix/st")
        #expect(StripID(.fxReturn, 3).mainLR == "/fxrtn/03/mix/st")
        #expect(StripID(.bus, 16).mainLR == "/bus/16/mix/st")
        #expect(StripID(.matrix, 1).mainLR == nil)
        #expect(StripID(.mainStereo).mainLR == nil)
        #expect(StripID(.mainMono).mainLR == nil)
        #expect(StripID(.dca, 1).mainLR == nil)
    }

    @Test func theMixTabReadsItAndTheDemoStartsInTheMainMix() {
        #expect(Catalog.tabAddresses(.mix, StripID(.input, 1), headamp: nil).contains("/ch/01/mix/st"))
        #expect(DemoState.values()["/ch/01/mix/st"] == .int(1))
        #expect(DemoState.values()["/bus/01/mix/st"] == .int(1))
    }

    /// The desk links `mix/st` with fader and mute, so the app writes one side and the desk copies it.
    @Test func takingALinkedPairOutReachesBothSides() async throws {
        try await withLiveDesk { fake, mirror in
            let gtrL = StripID(.input, 9)
            await openTab(.mix, of: gtrL, in: mirror)
            #expect(mirror.isInMainLR(gtrL) == true)

            mirror.setInMainLR(gtrL, false)

            #expect(await eventually { fake.value(at: "/ch/10/mix/st") == .int(0) })
            #expect(fake.value(at: "/ch/09/mix/st") == .int(0))
            #expect(mirror.isInMainLR(gtrL) == false)
        }
    }

    @Test func aMatrixHasNoAnswer() {
        #expect(ConsoleMirror.preview().isInMainLR(StripID(.matrix, 1)) == nil)
    }
}

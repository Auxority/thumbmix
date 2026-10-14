import Testing

@testable import ThumbmixCore

/// Inserts (doc p.26 for channels; the same block for buses, matrices and the mains): on, position and slot.
struct InsertTests {
    @Test func insertsExistWhereTheDeskHasThem() {
        #expect(Catalog.insert(StripID(.input, 3))?.on.address == "/ch/03/insert/on")
        #expect(Catalog.insert(StripID(.bus, 16))?.position.address == "/bus/16/insert/pos")
        #expect(Catalog.insert(StripID(.matrix, 6))?.slot.address == "/mtx/06/insert/sel")
        #expect(Catalog.insert(StripID(.mainStereo))?.on.address == "/main/st/insert/on")
        #expect(Catalog.insert(StripID(.mainMono))?.on.address == "/main/m/insert/on")
        for kind in [StripKind.auxIn, .fxReturn, .dca] { #expect(Catalog.insert(StripID(kind)) == nil) }
    }

    @Test func slotsAreTheDesksTwentyThree() {
        #expect(Catalog.insertSlots.count == 23)
        #expect(Catalog.insertSlots.first == "OFF")
        #expect(Catalog.insertSlots[9] == "FX5L")
        #expect(Catalog.insertSlots.last == "AUX6")
    }

    /// Read when the Mix tab opens, with the effect each FX slot holds.
    @Test func theMixTabReadsTheInsertAndTheEffects() {
        let channel = Catalog.tabAddresses(.mix, StripID(.input, 1), headamp: nil)
        #expect(channel.contains("/ch/01/insert/sel"))
        #expect(channel.contains("/fx/5/type"))
        let auxIn = Catalog.tabAddresses(.mix, StripID(.auxIn, 1), headamp: nil)
        #expect(!auxIn.contains("/fx/5/type"))
    }

    @Test func theDemoStartsWithTypedInserts() {
        let demo = DemoState.values()
        #expect(demo["/ch/01/insert/on"] == .int(0), "an int toggle, off; not the generic /on")
        #expect(demo["/ch/01/insert/pos"] == .int(1))
        #expect(demo["/ch/01/insert/sel"] == .int(0))
        #expect(demo["/fx/5/type"] == .int(4), "Dual DeEsser")
        #expect(demo["/ch/13/insert/sel"] == .int(9), "Vox 1 on FX5 L")
        #expect(demo["/ch/13/insert/on"] == .int(1))
        #expect(demo["/ch/08/insert/sel"] == .int(19), "Bass on Aux out 3")
    }
}

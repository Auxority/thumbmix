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

    /// No source says which Link Preference carries the insert (searched 2026-10-14). Dynamics is assumed: a wrong
    /// guess shows per-side blocks, and after the first edit Gate and Comp go per side too until reconnect (fails safe).
    @Test func insertsFollowTheDynamicsLink() {
        #expect(LinkSection.of(suffix: "/insert/on") == .dynamics)
        #expect(LinkSection.of(suffix: "/insert/pos") == .dynamics)
    }

    @MainActor @Test func aLinkedPairShowsOneBlock() {
        let mirror = ConsoleMirror.preview()
        let gtr = StripID(.input, 9)
        #expect(mirror.insertBlocks(gtr, partner: gtr.partner) == [[gtr, StripID(.input, 10)]])
        #expect(mirror.insertBlocks(StripID(.input, 13), partner: nil) == [[StripID(.input, 13)]])
    }

    @MainActor @Test func unsharedPairShowsBlocksPerSide() {
        var state = DemoState.values()
        state[LinkSection.dynamics.preferenceAddress] = .int(0)
        let mirror = ConsoleMirror.preview(state)
        let gtr = StripID(.input, 9)
        #expect(mirror.insertBlocks(gtr, partner: gtr.partner) == [[gtr], [StripID(.input, 10)]])
    }
}

/// The block shows On and Position as live controls, so it needs every side's slot, On and Position from the desk.
extension InsertTests {
    @MainActor @Test func anInsertIsReadOnlyOnceEverySideSentSlotOnAndPosition() {
        let gtr = StripID(.input, 9)
        let pair = [gtr, StripID(.input, 10)]
        #expect(ConsoleMirror.preview().isInsertRead(pair))
        for address in ["/ch/09/insert/sel", "/ch/10/insert/on", "/ch/10/insert/pos"] {
            var state = DemoState.values()
            state[address] = nil
            #expect(!ConsoleMirror.preview(state).isInsertRead(pair), "\(address) unread")
        }
    }

    @MainActor @Test func aSlotReadWithOnUnreadIsNotAReadInsert() {
        var state = DemoState.values()
        state["/ch/13/insert/on"] = nil
        let mirror = ConsoleMirror.preview(state)
        #expect(mirror.insertSlot(StripID(.input, 13)) != nil)
        #expect(!mirror.isInsertRead([StripID(.input, 13)]))
    }

    @MainActor @Test func aPairWhoseSidesAgreeStaysOneBlock() {
        let gtr = StripID(.input, 9)
        let mirror = ConsoleMirror.preview()
        #expect(mirror.insertBlocks(gtr, partner: gtr.partner) == [[gtr, StripID(.input, 10)]])
    }

    @MainActor @Test func aPairWhoseOnDiffersShowsBlocksPerSide() {
        var state = DemoState.values()
        state["/ch/09/insert/on"] = .int(1)
        state["/ch/10/insert/on"] = .int(0)
        let gtr = StripID(.input, 9)
        #expect(ConsoleMirror.preview(state).insertBlocks(gtr, partner: gtr.partner) == [[gtr], [StripID(.input, 10)]])
    }

    @MainActor @Test func aPairWhosePositionDiffersShowsBlocksPerSide() {
        var state = DemoState.values()
        state["/ch/09/insert/pos"] = .int(0)
        state["/ch/10/insert/pos"] = .int(1)
        let gtr = StripID(.input, 9)
        #expect(ConsoleMirror.preview(state).insertBlocks(gtr, partner: gtr.partner) == [[gtr], [StripID(.input, 10)]])
    }

    @MainActor @Test func aPairWithOneSideUnreadStaysOneBlock() {
        var state = DemoState.values()
        state["/ch/09/insert/on"] = .int(1)
        state["/ch/10/insert/on"] = nil
        let gtr = StripID(.input, 9)
        #expect(ConsoleMirror.preview(state).insertBlocks(gtr, partner: gtr.partner) == [[gtr, StripID(.input, 10)]])
    }

    @MainActor @Test func aSlotDiffersButOnAndPositionAgreeStaysOneBlock() {
        var state = DemoState.values()
        state["/ch/09/insert/sel"] = .int(9)
        state["/ch/10/insert/sel"] = .int(10)
        let gtr = StripID(.input, 9)
        #expect(ConsoleMirror.preview(state).insertBlocks(gtr, partner: gtr.partner) == [[gtr, StripID(.input, 10)]])
    }
}

/// An unverified section a partner didn't follow is shown per side and the partner isn't written (see LinkSyncTests).
@MainActor
struct InsertLinkSyncTests {
    @Test func aPartnerThatDoesNotFollowAnInsertEditIsShownPerSideNotWritten() async throws {
        try await withLiveDesk(copiesLinkedEdits: false) { fake, mirror in
            let gtr = StripID(.input, 9)
            await openTab(.mix, of: gtr, in: mirror)
            let onR = "/ch/10/insert/on"
            let before = fake.value(at: onR)
            #expect(mirror.insertBlocks(gtr, partner: gtr.partner).count == 1)

            mirror.set("/ch/09/insert/on", .int(1))

            #expect(await eventually { mirror.insertBlocks(gtr, partner: gtr.partner).count == 2 }, "per side now")
            #expect(fake.value(at: onR) == before)
            #expect(!fake.receivedSets.contains { $0.address == onR })
        }
    }
}

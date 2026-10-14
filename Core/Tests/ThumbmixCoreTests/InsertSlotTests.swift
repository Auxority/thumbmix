import Testing

@testable import ThumbmixCore

struct InsertSlotTests {
    @Test func selDecodesInTheDesksOrder() {
        #expect(InsertSlot(sel: 0) == InsertSlot.none)
        #expect(InsertSlot(sel: 1) == .fx(1, right: false))
        #expect(InsertSlot(sel: 10) == .fx(5, right: true))
        #expect(InsertSlot(sel: 16) == .fx(8, right: true))
        #expect(InsertSlot(sel: 17) == .aux(1))
        #expect(InsertSlot(sel: 22) == .aux(6))
    }

    @Test func outOfRangeSelIsUnread() {
        #expect(InsertSlot(sel: 23) == nil)
        #expect(InsertSlot(sel: -1) == nil)
    }

    @Test func labelsNameTheSlotAndItsEffect() {
        #expect(InsertSlot.fx(5, right: false).label(effect: "Dual DeEsser") == "FX5 L · Dual DeEsser")
        #expect(InsertSlot.fx(5, right: false).label(effect: nil) == "FX5 L")
        #expect(InsertSlot.aux(1).label(effect: nil) == "Aux out 1 · outboard")
        #expect(InsertSlot.none.label(effect: nil) == "None")
    }

    /// The two lists differ: index 4 is a Chamber Reverb on FX1-4 and a Dual DeEsser on FX5-8 (doc p.166).
    @Test func effectNamesFollowTheSlotsList() {
        #expect(FXEffects.name(fx: 1, type: 4) == "Chamber Reverb")
        #expect(FXEffects.name(fx: 5, type: 4) == "Dual DeEsser")
        #expect(FXEffects.name(fx: 1, type: 60) == "Stereo Pitch")
        #expect(FXEffects.name(fx: 8, type: 33) == "Suboctaver")
    }

    @Test func unknownEffectTypeDropsTheName() {
        #expect(FXEffects.name(fx: 5, type: 34) == nil)
        #expect(FXEffects.name(fx: 1, type: -1) == nil)
    }

    @Test func aPairOnBothHalvesOfOneFXReadsOnce() {
        let label = InsertSlot.pairLabel(.fx(5, right: false), .fx(5, right: true)) { _ in "Dual DeEsser" }
        #expect(label == "FX5 L / R · Dual DeEsser")
    }

    @Test func aPairOnDifferentSlotsNamesBoth() {
        #expect(InsertSlot.pairLabel(.fx(5, right: false), .aux(2)) { _ in "Dual DeEsser" } == "FX5 L / Aux out 2")
        #expect(InsertSlot.pairLabel(.aux(1), .aux(1)) { _ in nil } == "Aux out 1 · outboard")
    }

    @Test func turningOnAnAuxSlotAsks() throws {
        let prompt = try #require(InsertPrompt(name: "Bass", turningOn: true, slots: [.aux(3)]))
        #expect(prompt.title == "Turn on the insert for Bass?")
        #expect(
            prompt.message
                == "Bass will play only what comes back from the gear on Aux out 3. If nothing is connected there, Bass goes silent."
        )
        #expect(prompt.confirm == "Turn On")
    }

    @Test func fxSlotsAndTurningOffNeverAsk() {
        #expect(InsertPrompt(name: "Vox 1", turningOn: true, slots: [.fx(5, right: false)]) == nil)
        #expect(InsertPrompt(name: "Bass", turningOn: false, slots: [.aux(3)]) == nil)
    }

    @Test func aPairWithAnAuxSideAsks() {
        let prompt = InsertPrompt(name: "Gtr", turningOn: true, slots: [.fx(5, right: false), .aux(2)])
        #expect(prompt?.message.contains("Aux out 2") == true)
    }

    @MainActor @Test func unreadSlotIsNil() {
        var state = DemoState.values()
        state["/ch/13/insert/sel"] = nil
        let mirror = ConsoleMirror.preview(state)
        #expect(mirror.insertSlot(StripID(.input, 13)) == nil)
        #expect(mirror.insertLabel([StripID(.input, 13)]) == nil)
    }

    @MainActor @Test func aFloatSlotCountsAsUnread() {
        var state = DemoState.values()
        state["/ch/13/insert/sel"] = .float(0.5)
        let mirror = ConsoleMirror.preview(state)
        #expect(mirror.insertSlot(StripID(.input, 13)) == nil)
    }

    @MainActor @Test func theMirrorLabelsVox1sDeEsser() {
        let mirror = ConsoleMirror.preview()
        #expect(mirror.insertSlot(StripID(.input, 13)) == .fx(5, right: false))
        #expect(mirror.insertLabel([StripID(.input, 13)]) == "FX5 L · Dual DeEsser")
    }
}

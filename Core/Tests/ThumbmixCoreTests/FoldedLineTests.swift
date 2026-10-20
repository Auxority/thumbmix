import Testing

@testable import ThumbmixCore

/// The one line each set-once block folds into (mocks 2026-10-20-fewer-options): what's inside, then its values.
@MainActor
struct FoldedLineTests {
    private let kick = StripID(.input, 1)
    private let gtrL = StripID(.input, 9)
    private let gtrR = StripID(.input, 10)
    private let vox = StripID(.input, 13)

    private func mirror(_ changes: [String: OSCArgument], forgetting forgotten: [String] = []) -> ConsoleMirror {
        var state = DemoState.values().merging(changes) { $1 }
        for address in forgotten { state[address] = nil }
        return ConsoleMirror.preview(state)
    }

    private var plainComp: [String: OSCArgument] {
        [
            "/ch/01/dyn/det": .int(1), "/ch/01/dyn/env": .int(1), "/ch/01/dyn/pos": .int(1), "/ch/01/dyn/keysrc": .int(0),
            "/ch/01/dyn/filter/on": .int(0),
        ]
    }

    @Test func theCompLineNamesItsSettingsAndTheirValues() {
        #expect(
            mirror(plainComp).compFold(kick, locale: .testEnglish)
                == FoldedLine(names: "Detector · Envelope · Position · Key", values: "RMS · LOG · After EQ · Self"))
    }

    @Test func aKeyFilterThatsOnJoinsTheLine() {
        let changes = plainComp.merging(
            ["/ch/01/dyn/filter/on": .int(1), "/ch/01/dyn/filter/type": .int(1), "/ch/01/dyn/filter/f": .float(0.5)]
        ) { $1 }
        let freq = ValueText.format(0.5, Catalog.dynamicsKey(kick).filterFrequency, locale: .testEnglish)
        #expect(mirror(changes).compFold(kick, locale: .testEnglish).values == "RMS · LOG · After EQ · Self · LC12 \(freq)")
    }

    /// A matrix's comp has a key filter but no source (doc p.32-37): the line still says what the key does.
    @Test func aMatrixCompHasNoSourceSoSaysFilterOff() {
        let line = mirror(["/mtx/01/dyn/filter/on": .int(0)]).compFold(StripID(.matrix, 1), locale: .testEnglish)
        #expect(line.values.hasSuffix(" · Filter off"))
    }

    @Test func theGateLineNamesItsKeySource() {
        let line = mirror(["/ch/01/gate/keysrc": .int(2), "/ch/01/gate/filter/on": .int(0)])
            .gateKeyFold(kick, locale: .testEnglish)
        #expect(line == FoldedLine(names: "Key", values: "Ch 2 · Snare"))
    }

    /// The safety rule: a value the desk never sent reads "—", never a default.
    @Test func anUnreadValueShowsADash() {
        let line = mirror(plainComp, forgetting: ["/ch/01/dyn/det"]).compFold(kick, locale: .testEnglish)
        #expect(line.values.hasPrefix("— · "))
    }

    @Test func theLineFollowsADeskChange() async throws {
        try await withLiveDesk(
            before: { fake in fake.deskChange("/ch/01/dyn/det", .int(1)) },
            body: { fake, mirror in
                mirror.read(.comp, of: kick)
                #expect(await eventually { mirror.compFold(kick, locale: .testEnglish).values.hasPrefix("RMS · ") })
                fake.deskChange("/ch/01/dyn/det", .int(0))
                #expect(await eventually { mirror.compFold(kick, locale: .testEnglish).values.hasPrefix("PEAK · ") })
            })
    }

    @Test func theInsertLineShowsSlotStateAndPosition() throws {
        let mirror = mirror(["/ch/13/insert/on": .int(1), "/ch/13/insert/pos": .int(0)])
        let line = mirror.insertFold([[vox]], locale: .testEnglish)
        #expect(line.names == "Insert · Before EQ")
        #expect(line.values == (try #require(mirror.insertLabel([vox]))))
        #expect(line.states == [true], "drawn as a green On (B, 2026-10-20)")
        #expect(line.text == line.values + " · On")
    }

    @Test func anInsertThatsOffSaysOff() {
        let line = mirror(["/ch/13/insert/on": .int(0)]).insertFold([[vox]], locale: .testEnglish)
        #expect(line.states == [false])
        #expect(line.text.hasSuffix(" · Off"))
    }

    @Test func aLineWithoutAStateHasNone() {
        let line = mirror(plainComp).compFold(kick, locale: .testEnglish)
        #expect(line.states.isEmpty)
        #expect(line.text == line.values)
    }

    /// A filter that's on but whose type or frequency wasn't read yet: one dash, not "— —".
    @Test func anUnreadFilterSettingShowsOneDash() {
        let changes = plainComp.merging(["/ch/01/dyn/filter/on": .int(1)]) { $1 }
        let line = mirror(changes, forgetting: ["/ch/01/dyn/filter/type", "/ch/01/dyn/filter/f"])
            .compFold(kick, locale: .testEnglish)
        #expect(line.values == "RMS · LOG · After EQ · Self · —")
    }

    @Test func anEmptySlotSaysSo() {
        let line = mirror(["/ch/01/insert/sel": .int(0)]).insertFold([[kick]], locale: .testEnglish)
        #expect(line.values == "No slot picked on the desk")
    }

    @Test func anUnreadInsertShowsADash() {
        let line = mirror([:], forgetting: ["/ch/13/insert/on"]).insertFold([[vox]], locale: .testEnglish)
        #expect(line == FoldedLine(names: "Insert", values: "—"))
    }

    /// A pair whose inserts the desk doesn't link, one side on: the line says both rather than picking one.
    @Test func aPairsInsertLineShowsBothStates() {
        let line = mirror([
            "/ch/09/insert/sel": .int(5), "/ch/10/insert/sel": .int(6),
            "/ch/09/insert/on": .int(1), "/ch/10/insert/on": .int(0), "/ch/09/insert/pos": .int(0),
            "/ch/10/insert/pos": .int(0),
        ]).insertFold([[gtrL], [gtrR]], locale: .testEnglish)
        #expect(line.names == "Insert · Gtr L / Gtr R · Before EQ")
        #expect(line.states == [true, false], "odd side first, each in its own colour")
        #expect(line.text.hasSuffix(" · On / Off"))
    }

    @Test func aSheetTitleNamesTheSideItEdits() {
        let mirror = ConsoleMirror.preview()
        #expect(mirror.sheetTitle("Comp", strip: gtrR, perSide: true) == "Comp · Gtr R")
        #expect(mirror.sheetTitle("Comp", strip: gtrL, perSide: false) == "Comp · " + mirror.pairName(gtrL))
        #expect(mirror.sheetTitle("Comp", strip: kick, perSide: false) == "Comp · Kick")
    }
}

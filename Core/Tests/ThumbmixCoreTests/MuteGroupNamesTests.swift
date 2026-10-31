import Testing

@testable import ThumbmixCore

/// A mute group has no name on the desk (doc p.21): the names live on the iPhone, per remembered console
/// (spec 2026-10-31-mute-group-names).
@MainActor
struct MuteGroupNamesTests {
    private let kick = StripID(.input, 1)
    private let gtrL = StripID(.input, 9)
    private let gtrR = StripID(.input, 10)

    private func offline() -> ConsoleMirror { ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9)) }

    /// Kick is in groups 1 and 2; the groups in `on` are switched on.
    private func mirror(on: [Int]) -> ConsoleMirror {
        let mirror = offline()
        mirror.apply(OSCMessage(kick.muteGroupMask!, [.int(0b11)]))
        for group in 1...Catalog.muteGroupCount {
            mirror.apply(OSCMessage(Catalog.muteGroup(group), [.int(on.contains(group) ? 1 : 0)]))
        }
        return mirror
    }

    // MARK: The names

    @Test func aNameFollowsTheStripNameRules() {
        var names = MuteGroupNames()
        names.set("  Bänd & Co. is a very long name ", for: 2)
        #expect(names.name(of: 2) == "Band & Co. i")
        #expect(names.name(of: 2)!.count <= StripName.maxLength)
    }

    @Test func anEmptyNameIsUnnamed() {
        var names = MuteGroupNames()
        names.set("Band", for: 2)
        names.set("   ", for: 2)
        #expect(names.name(of: 2) == nil)
        #expect(names == MuteGroupNames())
    }

    @Test func aGroupTheDeskDoesNotHaveTakesNoName() {
        var names = MuteGroupNames()
        names.set("Band", for: 0)
        names.set("Band", for: Catalog.muteGroupCount + 1)
        #expect(names == MuteGroupNames())
    }

    @Test func namesSurviveBeingStored() {
        var names = MuteGroupNames()
        names.set("Band", for: 2)
        names.set("FX", for: 6)
        #expect(MuteGroupNames(stored: names.stored) == names)
    }

    @Test func storedJunkIsIgnored() {
        let stored: [String: Any] = ["2": "Band", "9": "Nope", "x": "Nope", "3": 7, "4": "  "]
        var expected = MuteGroupNames()
        expected.set("Band", for: 2)
        #expect(MuteGroupNames(stored: stored) == expected)
        #expect(MuteGroupNames(stored: nil) == MuteGroupNames())
        #expect(MuteGroupNames(stored: "text") == MuteGroupNames())
    }

    // MARK: Per console

    @Test func eachConsoleKeepsItsOwnNames() {
        var book = MuteGroupNameBook()
        var fontein = MuteGroupNames()
        fontein.set("Band", for: 2)
        var zaal = MuteGroupNames()
        zaal.set("Choir", for: 2)
        book.set(fontein, of: "De Fontein FOH@192.168.1.62")
        book.set(zaal, of: "Zaal 2@10.10.0.20")
        #expect(book.names(of: "De Fontein FOH@192.168.1.62").name(of: 2) == "Band")
        #expect(book.names(of: "Zaal 2@10.10.0.20").name(of: 2) == "Choir")
        #expect(book.names(of: "Other@10.0.0.1") == MuteGroupNames())
    }

    @Test func aBookSurvivesBeingStoredAndDropsEmptyEntries() {
        var book = MuteGroupNameBook()
        var names = MuteGroupNames()
        names.set("Band", for: 2)
        book.set(names, of: "A@1.1.1.1")
        book.set(MuteGroupNames(), of: "B@1.1.1.2")
        #expect(MuteGroupNameBook(stored: book.stored) == book)
        #expect(book.stored.keys.sorted() == ["A@1.1.1.1"])
        #expect(MuteGroupNameBook(stored: ["A": "junk", "B": ["1": "Ok"]]).names(of: "B").name(of: 1) == "Ok")
    }

    @Test func aForgottenConsoleTakesItsNamesAlong() {
        var book = MuteGroupNameBook()
        var names = MuteGroupNames()
        names.set("Band", for: 2)
        book.set(names, of: "A@1.1.1.1")
        book.forget("A@1.1.1.1")
        #expect(book.names(of: "A@1.1.1.1") == MuteGroupNames())
    }

    // MARK: On the mirror

    @Test func renamingChangesTheMirrorAndTellsTheApp() {
        let mirror = offline()
        var told: [MuteGroupNames] = []
        mirror.onMuteGroupNamesChanged = { told.append($0) }
        mirror.renameMuteGroup(2, to: "Band")
        #expect(mirror.muteGroupName(2) == "Band")
        #expect(mirror.muteGroupName(1) == nil)
        #expect(told.map { $0.name(of: 2) } == ["Band"])
    }

    @Test func aTitleFallsBackToTheNumber() {
        let mirror = offline()
        mirror.renameMuteGroup(2, to: "Band")
        #expect(mirror.muteGroupTitle(2) == "Band")
        #expect(mirror.muteGroupTitle(3) == "Group 3")
        #expect(mirror.muteGroupLine(2) == "Group 2 (Band)")
        #expect(mirror.muteGroupLine(3) == "Group 3")
    }

    @Test func aStripNamesTheFirstGroupThatIsOnAndHasHim() {
        let mirror = mirror(on: [2])
        #expect(mirror.mutingGroup(of: kick) == 2)
        mirror.apply(OSCMessage(Catalog.muteGroup(1), [.int(1)]))
        #expect(mirror.mutingGroup(of: kick) == 1)
        mirror.apply(OSCMessage(Catalog.muteGroup(1), [.int(0)]))
        mirror.apply(OSCMessage(Catalog.muteGroup(2), [.int(0)]))
        #expect(mirror.mutingGroup(of: kick) == nil)
        #expect(mirror.mutedByText(of: kick) == nil)
    }

    @Test func aGroupThatIsOnIsNamedForVoiceOverByNameOrNumber() {
        let mirror = mirror(on: [2])
        #expect(mirror.mutedByText(of: kick) == "Muted by mute group 2")
        mirror.renameMuteGroup(2, to: "Band")
        #expect(mirror.mutedByText(of: kick) == "Muted by Band")
    }

    @Test func aPairIsMutedByEitherSidesGroup() {
        let mirror = mirror(on: [3])
        mirror.apply(OSCMessage(gtrL.linkAddress!, [.int(1)]))
        mirror.apply(OSCMessage(gtrL.muteGroupMask!, [.int(0)]))
        mirror.apply(OSCMessage(gtrR.muteGroupMask!, [.int(0b100)]))
        mirror.renameMuteGroup(3, to: "FX")
        #expect(mirror.mutingGroup(of: gtrL) == 3)
        #expect(mirror.mutedByText(of: gtrL) == "Muted by FX")
    }

    /// An unnamed group adds nothing to the caption, as before; a named one only while it's on.
    @Test func theRowCaptionGainsTheGroupNameWhileItIsOn() {
        let mirror = mirror(on: [])
        mirror.renameMuteGroup(2, to: "Band")
        #expect(mirror.rowCaption("1", of: kick) == "1")
        mirror.apply(OSCMessage(Catalog.muteGroup(2), [.int(1)]))
        #expect(mirror.rowCaption("1", of: kick) == "1 · Band")
        #expect(mirror.rowCaption("", of: kick) == "Band", "the mains have no number")
        mirror.renameMuteGroup(2, to: "")
        #expect(mirror.rowCaption("1", of: kick) == "1")
    }
}

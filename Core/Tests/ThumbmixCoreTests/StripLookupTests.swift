import Testing

@testable import ThumbmixCore

/// A client names a strip by id or by the desk's name; a guess that fits several strips is an error, never a pick.
struct StripLookupTests {
    private let kick = StripID(.input, 1)
    private let headset1 = StripID(.input, 5)
    private let headset2 = StripID(.input, 6)
    private let bassGuitar = StripID(.input, 7)
    private let bassDrum = StripID(.input, 8)
    private let cafe = StripID(.input, 9)

    private var lookup: StripLookup {
        StripLookup(entries: [
            .init(strip: kick, names: ["Kick", "Ch 1"]), .init(strip: headset1, names: ["Headset 1", "Ch 5"]),
            .init(strip: headset2, names: ["Headset 2", "Ch 6"]), .init(strip: bassGuitar, names: ["Bass Guitar", "Ch 7"]),
            .init(strip: bassDrum, names: ["Bass Drum", "Ch 8"]), .init(strip: cafe, names: ["Café", "Ch 9"]),
            .init(strip: StripID(.bus, 3), names: ["Mon 3", "Bus 3"]),
        ])
    }

    @Test func idsRoundTripForEveryStrip() {
        for strip in StripKind.allCases.flatMap(StripID.all) {
            let id = StripLookup.id(of: strip)
            #expect(!id.hasPrefix("/"))
            #expect(StripLookup.strip(withID: id) == strip, "\(id)")
        }
        #expect(StripLookup.id(of: kick) == "ch/01")
        #expect(StripLookup.id(of: StripID(.dca, 2)) == "dca/2")
        #expect(StripLookup.id(of: StripID(.mainStereo)) == "main/st")
    }

    @Test func idsAreReadLeniently() {
        #expect(StripLookup.strip(withID: "ch/1") == kick)
        #expect(StripLookup.strip(withID: "/CH/01") == kick)
        #expect(StripLookup.strip(withID: " bus/3 ") == StripID(.bus, 3))
    }

    @Test func badIdsAreNotStrips() {
        for id in ["ch/33", "ch/0", "ch", "ch/x", "dca/9", "main/x", "foo/1", "", "ch/01/eq"] {
            #expect(StripLookup.strip(withID: id) == nil, "\(id)")
        }
    }

    @Test func anIdWins() {
        #expect(lookup.match("ch/05") == .found(headset1))
    }

    @Test func aNameIgnoresCaseAndDiacritics() {
        #expect(lookup.match("KICK") == .found(kick))
        #expect(lookup.match("cafe") == .found(cafe))
        #expect(lookup.match("  headset   1 ") == .found(headset1))
    }

    @Test func theDefaultNameOfAnUnnamedStripWorks() {
        #expect(lookup.match("ch 1") == .found(kick))
    }

    @Test func anExactNameBeatsALongerOneThatContainsIt() {
        let lookup = StripLookup(entries: [
            .init(strip: kick, names: ["Bass", "Ch 1"]), .init(strip: bassGuitar, names: ["Bass Guitar", "Ch 7"]),
        ])
        #expect(lookup.match("bass") == .found(kick))
    }

    @Test func aPartOfOneNameIsEnough() {
        #expect(lookup.match("guitar") == .found(bassGuitar))
    }

    @Test func aGuessThatFitsSeveralIsAmbiguous() {
        #expect(lookup.match("bass") == .ambiguous([bassGuitar, bassDrum]))
        #expect(lookup.match("headset") == .ambiguous([headset1, headset2]))
    }

    @Test func aNameNobodyHasIsUnknown() {
        #expect(lookup.match("trombone") == .unknown)
        #expect(lookup.match("") == .unknown)
        #expect(lookup.match("   ") == .unknown)
    }
}

import Testing

@testable import ThumbmixCore

/// Stereo links (doc p.19-20): which pairs exist, which Link Preference governs a parameter, and what the mirror
/// answers about a pair.
@MainActor
struct LinkModelTests {
    private let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))

    @Test func linkAddressesPerGroup() {
        #expect(StripID(.input, 7).linkAddress == "/config/chlink/7-8")
        #expect(StripID(.input, 8).linkAddress == "/config/chlink/7-8")
        #expect(StripID(.auxIn, 3).linkAddress == "/config/auxlink/3-4")
        #expect(StripID(.fxReturn, 8).linkAddress == "/config/fxlink/7-8")
        #expect(StripID(.bus, 16).linkAddress == "/config/buslink/15-16")
        #expect(StripID(.dca, 1).linkAddress == nil)
        #expect(StripID(.mainStereo).linkAddress == nil)
    }

    @Test func partnerIsTheOtherSideOfTheOddEvenPair() {
        #expect(StripID(.input, 7).partner == StripID(.input, 8))
        #expect(StripID(.input, 8).partner == StripID(.input, 7))
        #expect(StripID(.input, 8).oddSide == StripID(.input, 7))
        #expect(StripID(.dca, 1).partner == nil)
    }

    @Test func linkablePartOfAnAddress() {
        let parsed = StripID.linkable(from: "/ch/09/eq/2/g")
        #expect(parsed?.strip == StripID(.input, 9))
        #expect(parsed?.suffix == "/eq/2/g")
        #expect(StripID.linkable(from: "/bus/12/mix/fader")?.strip == StripID(.bus, 12))
        #expect(StripID.linkable(from: "/dca/1/fader") == nil)
        #expect(StripID.linkable(from: "/headamp/044/gain") == nil)
    }

    @Test(arguments: [
        ("/mix/fader", LinkSection.faderMute), ("/mix/on", .faderMute), ("/mix/03/level", .faderMute),
        ("/eq/2/g", .eq), ("/eq/on", .eq), ("/preamp/hpf", .eq), ("/preamp/trim", .gainDelay),
        ("/gate/thr", .dynamics), ("/dyn/ratio", .dynamics),
    ])
    func sectionOfAParameter(suffix: String, section: LinkSection) {
        #expect(LinkSection.of(suffix: suffix) == section)
    }

    @Test func panAndLabelsAreNeverShared() {
        #expect(LinkSection.of(suffix: "/mix/pan") == nil)
        #expect(LinkSection.of(suffix: "/config/name") == nil)
        #expect(LinkSection.of(suffix: "/grp/dca") == nil)
    }

    @Test func preferencesInDeskOrder() {
        #expect(
            LinkSection.allCases.map(\.preferenceAddress) == [
                "/config/linkcfg/hadly", "/config/linkcfg/eq", "/config/linkcfg/dyn", "/config/linkcfg/fdrmute",
            ])
    }

    /// Unread counts as separate: each side then shows its own value, which is never wrong.
    @Test func unreadPreferenceIsSeparate() {
        #expect(!mirror.isShared(.eq))
        mirror.apply(OSCMessage("/config/linkcfg/eq", [.int(1)]))
        #expect(mirror.isShared(.eq))
    }

    @Test func linkedFollowsTheDesk() {
        mirror.apply(OSCMessage("/config/chlink/9-10", [.int(1)]))
        #expect(mirror.isLinked(StripID(.input, 10)))
        #expect(!mirror.isLinked(StripID(.input, 11)))
    }

    @Test func partnerAddressOnlyForASharedSectionOfALinkedPair() {
        mirror.apply(OSCMessage("/config/linkcfg/fdrmute", [.int(1)]))
        mirror.apply(OSCMessage("/config/linkcfg/eq", [.int(0)]))
        #expect(mirror.partnerAddress(of: "/ch/09/mix/fader") == nil, "not linked yet")
        mirror.apply(OSCMessage("/config/chlink/9-10", [.int(1)]))
        #expect(mirror.partnerAddress(of: "/ch/09/mix/fader") == "/ch/10/mix/fader")
        #expect(mirror.partnerAddress(of: "/ch/10/mix/on") == "/ch/09/mix/on")
        #expect(mirror.partnerAddress(of: "/ch/09/eq/1/g") == nil, "EQ isn't linked on this desk")
        #expect(mirror.partnerAddress(of: "/ch/09/mix/pan") == nil)
    }

    /// Gain lives on the headamp, not the channel: a shared gain reaches the partner input's own preamp.
    @Test func partnerOfAHeadampIsThePartnerInputsHeadamp() {
        mirror.apply(OSCMessage("/config/linkcfg/hadly", [.int(1)]))
        mirror.apply(OSCMessage("/config/chlink/9-10", [.int(1)]))
        mirror.apply(OSCMessage(Catalog.headampIndex(forInput: 9), [.int(40)]))
        mirror.apply(OSCMessage(Catalog.headampIndex(forInput: 10), [.int(41)]))
        #expect(mirror.partnerAddress(of: "/headamp/040/gain") == "/headamp/041/gain")
        #expect(mirror.partnerAddress(of: "/headamp/041/phantom") == "/headamp/040/phantom")
        #expect(mirror.partnerAddress(of: "/headamp/050/gain") == nil, "feeds no linked input")
    }

    @Test func pairNameFromBothSides() {
        mirror.apply(OSCMessage("/ch/09/config/name", [.string("Gtr L")]))
        mirror.apply(OSCMessage("/ch/10/config/name", [.string("Gtr R")]))
        #expect(mirror.pairName(StripID(.input, 10)) == "Gtr")
        #expect(mirror.pairName(StripID(.input, 31)) == "Ch 31-32")
    }
}

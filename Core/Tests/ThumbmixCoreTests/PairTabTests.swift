import Testing

@testable import ThumbmixCore

/// A pair's tab looks like a mono tab while the desk links its section, and offers L | R when it doesn't.
@MainActor
struct PairTabTests {
    private let mirror = ConsoleMirror.preview()
    private let gtrL = StripID(.input, 9)

    @Test func tabsBelongToTheDesksLinkPreferences() {
        #expect(ChannelTab.mix.linkSection == .faderMute)
        #expect(ChannelTab.sends.linkSection == .faderMute)
        #expect(ChannelTab.input.linkSection == .gainDelay)
        #expect(ChannelTab.eq.linkSection == .eq)
        #expect(ChannelTab.gate.linkSection == .dynamics)
        #expect(ChannelTab.comp.linkSection == .dynamics)
        #expect(ChannelTab.fedBy.linkSection == nil)
        #expect(ChannelTab.members.linkSection == nil)
    }

    @Test func aSharedSectionNeedsNoSidePicker() {
        #expect(mirror.unlinkedSection(of: .eq, for: gtrL) == nil)
    }

    @Test func anUnlinkedSectionOfAPairNeedsTheSidePicker() {
        mirror.apply(OSCMessage(LinkSection.eq.preferenceAddress, [.int(0)]))
        #expect(mirror.unlinkedSection(of: .eq, for: gtrL) == .eq)
        #expect(mirror.unlinkedSection(of: .comp, for: gtrL) == nil)
    }

    @Test func aMonoStripNeverNeedsIt() {
        mirror.apply(OSCMessage(LinkSection.eq.preferenceAddress, [.int(0)]))
        #expect(mirror.unlinkedSection(of: .eq, for: StripID(.input, 1)) == nil)
    }
}

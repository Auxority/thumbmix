import FakeM32
import Testing

@testable import ThumbmixCore

/// A strip's edit sheet ticks its DCAs and mute groups as a draft, sent with the name on Done (spec 2026-10-19 §4).
/// The demo desk has Kick (Ch 1) on DCA 1 and in mute group 1, and the linked guitars (Ch 9-10) on DCA 2.
@MainActor
struct MembershipDraftTests {
    private let kick = StripID(.input, 1)
    private let gtrL = StripID(.input, 9)
    private let gtrR = StripID(.input, 10)

    private func toggle(_ group: Membership, of strip: StripID, in draft: inout MembershipDraft, _ mirror: ConsoleMirror) {
        draft.toggle(group, current: mirror.assignment(of: strip, to: group))
    }

    @Test func doneWritesTheTickedGroups() async throws {
        try await withLiveDesk { fake, mirror in
            var draft = MembershipDraft()
            toggle(.dca(2), of: kick, in: &draft, mirror)
            toggle(.muteGroup(2), of: kick, in: &draft, mirror)
            #expect(fake.value(at: kick.dcaMask!) == .int(0b1), "nothing sent before Done")
            mirror.apply(draft, to: [kick])
            #expect(await eventually { fake.value(at: kick.dcaMask!) == .int(0b11) })
            #expect(await eventually { fake.value(at: kick.muteGroupMask!) == .int(0b11) })
        }
    }

    /// Done writes only what the engineer ticked, onto the mask as the desk holds it then.
    @Test func doneKeepsBitsTheDeskChangedMeanwhile() async throws {
        try await withLiveDesk { fake, mirror in
            var draft = MembershipDraft()
            toggle(.dca(2), of: kick, in: &draft, mirror)
            fake.deskChange(kick.dcaMask!, .int(0b101))
            #expect(await eventually { mirror.cell(kick.dcaMask!).argument == .int(0b101) })
            mirror.apply(draft, to: [kick])
            #expect(await eventually { fake.value(at: kick.dcaMask!) == .int(0b111) })
        }
    }

    @Test func aTickToggledBackSendsNothing() async throws {
        try await withLiveDesk { fake, mirror in
            var draft = MembershipDraft()
            toggle(.dca(2), of: kick, in: &draft, mirror)
            draft.toggle(.dca(2), current: mirror.assignment(of: kick, to: .dca(2)))
            #expect(draft.isEmpty)
            mirror.apply(draft, to: [kick])
            mirror.toggleMuteGroup(6)
            #expect(await eventually { fake.value(at: "/config/mute/6") == .int(1) }, "a later set arrived")
            #expect(!fake.receivedSets.contains { $0.address == kick.dcaMask! })
        }
    }

    @Test func aHalfPairTicksToBothSides() async throws {
        try await withLiveDesk(
            before: { $0.deskChange("/ch/10/grp/dca", .int(0)) },
            body: { fake, mirror in
                var draft = MembershipDraft()
                let current = mirror.assignment(of: gtrL, to: .dca(2))
                #expect(draft.shown(.dca(2), current: current) == .leftOnly)
                draft.toggle(.dca(2), current: current)
                #expect(draft.shown(.dca(2), current: current) == .assigned)
                mirror.apply(draft, to: [gtrL, gtrR])
                #expect(await eventually { fake.value(at: gtrR.dcaMask!) == .int(0b10) })
                #expect(fake.value(at: gtrL.dcaMask!) == .int(0b10))
            })
    }

    /// A side whose mask went unread before Done (a resync) holds back the whole pair: never half a stereo source.
    @Test func aPairIsWrittenWholeOrNotAtAll() async throws {
        try await withLiveDesk { fake, mirror in
            var draft = MembershipDraft()
            toggle(.dca(3), of: gtrL, in: &draft, mirror)
            mirror.cell(gtrR.dcaMask!).argument = nil
            mirror.apply(draft, to: [gtrL, gtrR])
            mirror.toggleMuteGroup(6)
            #expect(await eventually { fake.value(at: "/config/mute/6") == .int(1) }, "a later set arrived")
            #expect(!fake.receivedSets.contains { $0.address == gtrL.dcaMask! })
        }
    }

    /// The sheet writes the shape it opened with, as its name fields do, even if the desk unlinked the pair meanwhile.
    @Test func doneWritesTheShapeTheSheetOpenedWith() async throws {
        try await withLiveDesk { fake, mirror in
            var draft = MembershipDraft()
            toggle(.dca(3), of: gtrL, in: &draft, mirror)
            fake.deskChange(gtrL.linkAddress!, .int(0))
            #expect(await eventually { !mirror.isLinked(gtrL) })
            mirror.apply(draft, to: [gtrL, gtrR])
            #expect(await eventually { fake.value(at: gtrR.dcaMask!) == .int(0b110) })
            #expect(fake.value(at: gtrL.dcaMask!) == .int(0b110))
        }
    }

    /// Half a pair already in a group that's on is silent already: the warning names only the side that mutes.
    @Test func aHalfPairNamesTheSideThatMutes() async throws {
        try await withLiveDesk(
            before: { fake in
                fake.deskChange("/ch/09/grp/mute", .int(0b10))
                fake.deskChange("/config/mute/2", .int(1))
            },
            body: { _, mirror in
                var draft = MembershipDraft()
                toggle(.muteGroup(2), of: gtrL, in: &draft, mirror)
                #expect(mirror.sidesMutedOnDone(draft, of: [gtrL, gtrR]) == [gtrR])
                var kicks = MembershipDraft()
                toggle(.muteGroup(2), of: kick, in: &kicks, mirror)
                #expect(mirror.sidesMutedOnDone(kicks, of: [kick]) == [kick])
            })
    }

    @Test func anUnreadMaskIgnoresTheDraft() {
        var draft = MembershipDraft()
        draft.toggle(.dca(1), current: .unread)
        #expect(draft.isEmpty)
    }

    @Test func joiningAnOnGroupIsNamed() async throws {
        try await withLiveDesk(
            before: { $0.deskChange("/config/mute/2", .int(1)) },
            body: { _, mirror in
                var draft = MembershipDraft()
                toggle(.muteGroup(2), of: kick, in: &draft, mirror)
                #expect(mirror.mutesOnDone(draft, of: kick) == [2])
                toggle(.muteGroup(1), of: kick, in: &draft, mirror)
                #expect(mirror.mutesOnDone(draft, of: kick) == [2], "leaving group 1 mutes nothing")
            })
    }

    @Test func aDCAHasNoGroupChoicesAndAMatrixOnlyMuteGroups() {
        let dca = ConsoleMirror.groupChoices(for: StripID(.dca, 1))
        #expect(dca.dcas.isEmpty && dca.muteGroups.isEmpty)
        let matrix = ConsoleMirror.groupChoices(for: StripID(.matrix, 1))
        #expect(matrix.dcas.isEmpty)
        #expect(matrix.muteGroups == (1...6).map { .muteGroup($0) })
        let input = ConsoleMirror.groupChoices(for: kick)
        #expect(input.dcas == (1...8).map { .dca($0) })
        #expect(input.muteGroups.count == 6)
    }
}

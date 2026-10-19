import FakeM32
import Testing

@testable import ThumbmixCore

/// The desk's six mute groups (spec 2026-10-19-mute-groups). The demo desk has the drums (Ch 1-7) in group 1 and the
/// vocals (Ch 13-14) in group 2, every group off.
@MainActor
struct MuteGroupTests {
    private let kick = StripID(.input, 1)
    private let bass = StripID(.input, 8)
    private let gtrL = StripID(.input, 9)
    private let gtrR = StripID(.input, 10)

    private func offline() -> ConsoleMirror { ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9)) }

    @Test func aTapSwitchesTheGroupOnTheDesk() async throws {
        try await withLiveDesk { fake, mirror in
            #expect(mirror.isMuteGroupOn(1) == false)
            mirror.toggleMuteGroup(1)
            #expect(await eventually { fake.value(at: "/config/mute/1") == .int(1) })
            #expect(mirror.isMuteGroupOn(1) == true)
        }
    }

    @Test func anUnreadGroupIgnoresATap() {
        let mirror = offline()
        #expect(mirror.isMuteGroupOn(1) == nil)
        mirror.toggleMuteGroup(1)
        #expect(mirror.cell("/config/mute/1").argument == nil)
    }

    @Test func aStripInAnOnGroupIsMutedByIt() async throws {
        try await withLiveDesk(
            before: { $0.deskChange("/config/mute/1", .int(1)) },
            body: { _, mirror in
                #expect(mirror.isMutedByGroup(kick))
                #expect(!mirror.isMutedByGroup(bass))
            })
    }

    @Test func anOffGroupMutesNobody() async throws {
        try await withLiveDesk { _, mirror in
            #expect(!mirror.isMutedByGroup(kick))
        }
    }

    @Test func aReadOnGroupCountsWhileAnotherIsUnread() {
        let mirror = offline()
        mirror.apply(OSCMessage(kick.muteGroupMask!, [.int(0b11)]))
        mirror.apply(OSCMessage("/config/mute/2", [.int(1)]))
        #expect(mirror.isMuteGroupOn(1) == nil)
        #expect(mirror.isMutedByGroup(kick))
    }

    @Test func anUnreadMaskIsNotMutedByAGroup() {
        let mirror = offline()
        mirror.apply(OSCMessage("/config/mute/1", [.int(1)]))
        #expect(!mirror.isMutedByGroup(kick))
    }

    /// The overview's pair row is driven by the odd side: half the pair silenced by a group must still show.
    @Test func aPairShowsTheBorderWhenEitherSideIsGroupMuted() {
        let mirror = offline()
        mirror.apply(OSCMessage(gtrL.linkAddress!, [.int(1)]))
        mirror.apply(OSCMessage(gtrL.muteGroupMask!, [.int(0)]))
        mirror.apply(OSCMessage(gtrR.muteGroupMask!, [.int(0b1)]))
        mirror.apply(OSCMessage("/config/mute/1", [.int(1)]))
        #expect(mirror.isMutedByGroup(gtrL))
    }

    /// The groups are read on connect, so a switch made on the desk while contact was lost shows once it's back.
    @Test func aGroupSwitchedOnTheDeskWhileLostShowsAfterTheResync() async throws {
        try await withLiveDesk { fake, mirror in
            fake.silent = true
            #expect(await eventually { !mirror.isLive })
            fake.deskChange("/config/mute/1", .int(1))
            fake.silent = false
            #expect(await eventually(timeout: .seconds(15)) { mirror.isLive && mirror.isMuteGroupOn(1) == true })
            #expect(mirror.isMutedByGroup(kick))
        }
    }

    /// A filled M means the strip's own mute; the red border, a group's. Both at once shows the strip's own.
    @Test func ownMuteWinsOverAGroup() {
        let mirror = offline()
        mirror.apply(OSCMessage(kick.muteGroupMask!, [.int(0b1)]))
        mirror.apply(OSCMessage("/config/mute/1", [.int(1)]))
        mirror.apply(OSCMessage(kick.on, [.int(0)]))
        #expect(mirror.muteLook(kick) == .muted)
        mirror.apply(OSCMessage(kick.on, [.int(1)]))
        #expect(mirror.muteLook(kick) == .mutedByGroup)
        mirror.apply(OSCMessage("/config/mute/1", [.int(0)]))
        #expect(mirror.muteLook(kick) == .off)
    }

    /// Whether the desk pushes a group switched on it is unverified: the Main page asks again each time it opens.
    @Test func reReadingTheGroupsCatchesASwitchTheDeskDidntPush() async throws {
        try await withLiveDesk(
            before: { $0.ignoresXremote = true },
            body: { fake, mirror in
                fake.deskChange("/config/mute/2", .int(1))
                mirror.readMuteGroups()
                #expect(await eventually { mirror.isMuteGroupOn(2) == true })
            })
    }

    @Test func membershipFlipsOnlyThisGroupsBit() async throws {
        try await withLiveDesk { fake, mirror in
            mirror.toggleAssignment(of: bass, to: .muteGroup(2))
            #expect(await eventually { fake.value(at: bass.muteGroupMask!) == .int(0b10) })
            mirror.toggleAssignment(of: kick, to: .muteGroup(2))
            #expect(await eventually { fake.value(at: kick.muteGroupMask!) == .int(0b11) })
        }
    }

    @Test func theMainsAndMatricesCanJoin() async throws {
        try await withLiveDesk { fake, mirror in
            mirror.toggleAssignment(of: StripID(.mainStereo), to: .muteGroup(3))
            #expect(await eventually { fake.value(at: "/main/st/grp/mute") == .int(0b100) })
            mirror.toggleAssignment(of: StripID(.matrix, 1), to: .muteGroup(3))
            #expect(await eventually { fake.value(at: "/mtx/01/grp/mute") == .int(0b100) })
        }
    }

    /// A group button names its strips; a linked pair once, by the name the overview gives its row.
    @Test func memberNamesListAPairOnce() {
        let mirror = offline()
        mirror.apply(OSCMessage(gtrL.linkAddress!, [.int(1)]))
        for (strip, name) in [(gtrL, "Gtr L"), (gtrR, "Gtr R"), (StripID(.input, 13), "Vox 1")] {
            mirror.apply(OSCMessage(strip.name, [.string(name)]))
            mirror.apply(OSCMessage(strip.muteGroupMask!, [.int(0b1)]))
        }
        #expect(mirror.muteGroupMemberNames(1) == [mirror.title(of: .pair(gtrL)), "Vox 1"])
        #expect(mirror.muteGroupMemberNames(2) == [])
    }

    @Test func everyStripWithAMuteMaskIsListed() {
        let strips = ConsoleMirror.muteGroupAssignableStrips
        #expect(strips.count == 72)
        #expect(strips.allSatisfy { $0.muteGroupMask != nil })
        #expect(strips.first == kick)
        #expect(strips.last == StripID(.mainMono))
    }

    /// Unused strips fold, but a member stays in view: its chip is the only place to see and undo it.
    @Test func aMemberNeverFoldsAndMatricesFoldToo() {
        let mirror = offline()
        let (mtx1, mtx2) = (StripID(.matrix, 1), StripID(.matrix, 2))
        for strip in [mtx1, mtx2] {
            mirror.apply(OSCMessage(strip.name, [.string("")]))
            mirror.apply(OSCMessage(strip.fader, [.float(0)]))
        }
        mirror.apply(OSCMessage(mtx1.muteGroupMask!, [.int(0b1)]))
        mirror.apply(OSCMessage(mtx2.muteGroupMask!, [.int(0)]))

        let unused = mirror.unusedStrips(notIn: .muteGroup(1))

        #expect(!unused.contains(mtx1))
        #expect(unused.contains(mtx2))
    }
}

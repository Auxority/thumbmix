import Foundation
import Testing

@testable import ThumbmixCore

/// A send's tap point as a chain of its strip's blocks (mock D3/S1): every block up to the tap reaches the mix,
/// and tapping a block takes the send right after it.
struct TapChainTests {
    private let vox = StripID(.input, 13)

    @Test func aChannelsChainFollowsItsSignal() {
        #expect(TapChain(source: vox, compBeforeEQ: false, stereoTarget: false).blocks == [.input, .gate, .eq, .comp, .fader, .group])
        #expect(TapChain(source: vox, compBeforeEQ: true, stereoTarget: false).blocks == [.input, .gate, .comp, .eq, .fader, .group])
    }

    /// A channel's chain ends in Subgroup: Pan on a stereo mix, whose pan it follows, Group on a mono one. A bus
    /// can't send as a subgroup at all.
    @Test func aChannelsChainEndsInSubgroup() {
        #expect(TapChain(source: vox, compBeforeEQ: false, stereoTarget: true).blocks.last == .pan)
        #expect(TapChain(source: vox, compBeforeEQ: false, stereoTarget: false).blocks.last == .group)
        let bus = TapChain(source: StripID(.bus, 1), compBeforeEQ: false, stereoTarget: true)
        #expect(bus.blocks == [.input, .eq, .comp, .fader], "no gate, no subgroup")
    }

    @Test func eachTapEndsWhereTheDeskTakesIt() {
        let chain = TapChain(source: vox, compBeforeEQ: false, stereoTarget: true)
        #expect(SendTap.allCases.map(chain.lastBlock) == [.input, .gate, .eq, .comp, .fader, .pan])
        #expect(chain.reaches(.eq, at: .postEQ))
        #expect(!chain.reaches(.comp, at: .postEQ))
    }

    /// With the comp before the EQ, a Pre-EQ send includes it (the user, from the desk; m32-probe 9b).
    @Test func aCompBeforeTheEQIsInAPreEQSend() {
        let chain = TapChain(source: vox, compBeforeEQ: true, stereoTarget: false)
        #expect(chain.lastBlock(.preEQ) == .comp)
        #expect(chain.lastBlock(.preFader) == .eq)
        #expect(chain.tap(afterTapping: .gate, current: .postFader) == .preEQ, "no tap sits between the gate and comp")
        #expect(chain.tap(afterTapping: .comp, current: .postFader) == .preEQ)
    }

    @Test func tappingABlockTakesTheSendRightAfterIt() {
        let chain = TapChain(source: vox, compBeforeEQ: false, stereoTarget: true)
        let after: [(TapBlock, SendTap)] = [
            (.input, .input), (.gate, .preEQ), (.eq, .postEQ), (.comp, .preFader), (.fader, .postFader), (.pan, .subgroup),
        ]
        for (block, tap) in after { #expect(chain.tap(afterTapping: block, current: .input) == tap || block == .input) }
        #expect(chain.tap(afterTapping: .input, current: .subgroup) == .input)
    }

    /// A second tap on the current tap point changes nothing: a nervous double tap must not move a monitor mix.
    @Test func tappingTheCurrentTapPointKeepsIt() {
        let chain = TapChain(source: vox, compBeforeEQ: true, stereoTarget: false)
        #expect(chain.tap(afterTapping: .comp, current: .preEQ) == .preEQ)
        #expect(chain.tap(afterTapping: .eq, current: .preFader) == .preFader, "Before fader ends at the EQ here")
    }

    @Test func theExplanationSaysWhatReachesTheMix() {
        let post = TapChain(source: vox, compBeforeEQ: false, stereoTarget: false)
        #expect(post.explanation(.preEQ, locale: .testEnglish) == "The gate reaches this mix; your EQ, comp, and fader don’t.")
        #expect(post.explanation(.postEQ, locale: .testEnglish) == "The gate and EQ reach this mix; your comp and fader don’t.")
        #expect(
            post.explanation(.input, locale: .testEnglish) == "Only the raw input reaches this mix: your gate, EQ, comp, and fader don’t.")
        let pre = TapChain(source: vox, compBeforeEQ: true, stereoTarget: false)
        #expect(pre.explanation(.postEQ, locale: .testEnglish) == "The gate, comp, and EQ reach this mix; your fader doesn’t.")
        let bus = TapChain(source: StripID(.bus, 1), compBeforeEQ: false, stereoTarget: false)
        #expect(bus.explanation(.postEQ, locale: .testEnglish) == "The EQ reaches this mix; your comp and fader don’t.")
    }

    /// Set on the desk, a mono mix's Subgroup must not look like After fader (the user, 2026-10-12).
    @Test func aMonoMixsSubgroupEndsInGroup() {
        let mono = TapChain(source: vox, compBeforeEQ: false, stereoTarget: false)
        #expect(mono.lastBlock(.subgroup) == .group)
        #expect(mono.tap(afterTapping: .group, current: .preFader) == .subgroup)
        #expect(mono.explanation(.subgroup, locale: .testEnglish) == "Follows your fader at a fixed 0 dB: the level here steps aside.")
    }

    @Test func namesSayItPlainlyAndTheDeskTermSpellsItOut() {
        #expect(SendTap.preFader.name == "Before fader")
        #expect(SendTap.preFader.deskTerm == "Pre-fader")
        #expect(SendTap(rawValue: 3) == .preFader, "the desk's own numbering (doc p.26)")
    }
}

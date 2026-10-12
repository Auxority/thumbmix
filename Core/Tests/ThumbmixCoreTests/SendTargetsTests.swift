import Testing

@testable import ThumbmixCore

/// A Sends tab lists the buses in pairs, as the desk keeps one tap point per pair (mock B, 2026-10-12): a linked pair
/// is one send, held by its odd side; an unlinked pair is two sends that share one ›.
@MainActor
struct SendTargetsTests {
    private let mirror = ConsoleMirror.preview()
    private let vox = StripID(.input, 13)

    @Test func unlinkedBusesComeInPairs() {
        let pairs = mirror.sendPairs(of: vox)
        #expect(pairs.count == 8)
        #expect(pairs.first == [StripID(.bus, 1), StripID(.bus, 2)])
        #expect(pairs.last == [StripID(.bus, 15), StripID(.bus, 16)])
    }

    @Test func aLinkedPairIsOneSendOnItsOddSide() {
        mirror.apply(OSCMessage("/config/buslink/5-6", [.int(1)]))
        let pairs = mirror.sendPairs(of: vox)
        #expect(pairs[2] == [StripID(.bus, 5)])
        #expect(pairs.count == 8)
    }

    @Test func aMainSendsToEveryMatrixInPairs() {
        #expect(mirror.sendPairs(of: StripID(.mainStereo)).flatMap { $0 } == StripID.all(.matrix))
    }
}

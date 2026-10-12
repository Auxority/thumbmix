import Testing

@testable import ThumbmixCore

/// A Sends tab shows a linked bus pair as one send, held by its odd side, like the desk does.
@MainActor
struct SendTargetsTests {
    private let mirror = ConsoleMirror.preview()
    private let vox = StripID(.input, 13)

    @Test func everyBusIsASendWhileNoneAreLinked() {
        #expect(mirror.sendTargets(of: vox) == StripID.all(.bus))
    }

    @Test func aLinkedPairIsOneSendOnItsOddSide() {
        mirror.apply(OSCMessage("/config/buslink/5-6", [.int(1)]))
        let targets = mirror.sendTargets(of: vox)
        #expect(targets.contains(StripID(.bus, 5)))
        #expect(!targets.contains(StripID(.bus, 6)))
        #expect(targets.count == 15)
    }

    /// The mains can't be linked: every matrix shows, and so does every send from a main.
    @Test func aMainSendsToEveryMatrix() {
        #expect(mirror.sendTargets(of: StripID(.mainStereo)) == StripID.all(.matrix))
    }
}

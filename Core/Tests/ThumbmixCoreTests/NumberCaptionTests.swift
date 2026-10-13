import Testing

@testable import ThumbmixCore

/// Sends and Fed by rows carry a named strip's desk number under its name, like the overview's (2026-10-13), so two
/// "Vox" rows can be told apart. Fed by mixes kinds, so the caption names the kind too: "Ch 1", not the overview's "1".
@MainActor
struct NumberCaptionTests {
    private let mirror = ConsoleMirror.preview()

    @Test func aNamedStripShowsItsKindAndNumber() {
        #expect(mirror.numberCaption(of: .strip(StripID(.input, 1), .full)) == "Ch 1")
        #expect(mirror.numberCaption(of: .strip(StripID(.bus, 1), .full)) == "Bus 1")
        #expect(mirror.numberCaption(of: .strip(StripID(.fxReturn, 1), .full)) == "FX 1")
        #expect(mirror.numberCaption(of: .strip(StripID(.mainStereo), .full)) == "Main LR")
    }

    @Test func aPairShowsBothNumbers() {
        #expect(mirror.numberCaption(of: .pair(StripID(.input, 9))) == "Ch 9-10")
        #expect(mirror.numberCaption(of: .strip(StripID(.input, 10), .bottom)) == "Ch 10")
    }

    /// An unnamed strip's title is already "Ch 20": a caption would only repeat it.
    @Test func anUnnamedRowHasNoCaption() {
        #expect(mirror.numberCaption(of: .strip(StripID(.input, 20), .full)) == nil)
        #expect(mirror.numberCaption(of: .pair(StripID(.input, 19))) == nil)
    }

    @Test func aPairWithOneNamedSideShowsItsNumbers() {
        mirror.apply(OSCMessage(StripID(.input, 20).name, [.string("Click")]))
        #expect(mirror.numberCaption(of: .pair(StripID(.input, 19))) == "Ch 19-20")
    }
}

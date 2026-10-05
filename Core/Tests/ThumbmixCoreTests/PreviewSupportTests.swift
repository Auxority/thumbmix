import Testing

@testable import ThumbmixCore

@MainActor
struct PreviewSupportTests {
    @Test func previewMirrorIsLiveWithTheDemoBand() {
        let mirror = ConsoleMirror.preview()
        #expect(mirror.isLive)
        #expect(mirror.name(StripID(.input, 1)) == "Kick")
        #expect(Catalog.syncAddresses().allSatisfy { mirror.cell($0).argument != nil })
    }

    @Test func previewMirrorStaysOffTheNetwork() {
        let mirror = ConsoleMirror.preview()
        #expect(!mirror.isRunning)
    }

    @Test func demoStateCoversEverySyncedAddress() {
        let state = DemoState.values()
        #expect(Catalog.syncAddresses().allSatisfy { state[$0] != nil })
    }
}

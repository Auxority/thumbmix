import FakeM32
import Testing

@testable import ThumbmixCore

/// The mains' Fed by (mock A, 2026-10-13): every strip with an LR switch feeds them. Main LR's row is that switch
/// (`mix/st`) and the strip's own fader, its level into LR; Main M's is the mono send, `mix/mono` and `mix/mlevel`
/// (doc p.25-31).
@MainActor
struct MainsFedByTests {
    private let kick = StripID(.input, 1)

    @Test func theMainsGetFedByLastLikeABus() {
        #expect(ChannelTab.tabs(for: .mainStereo) == [.mix, .eq, .comp, .sends, .fedBy])
        #expect(ChannelTab.tabs(for: .mainMono) == [.mix, .eq, .comp, .sends, .fedBy])
    }

    @Test func everyStripWithAnLRSwitchFeedsTheMains() {
        #expect(StripKind.mainStereo.feeders == [.input, .auxIn, .fxReturn, .bus])
        #expect(StripKind.mainMono.feeders == [.input, .auxIn, .fxReturn, .bus])
        #expect(StripKind.allCases.flatMap(StripID.all).filter { $0.mainLR != nil }.map(\.kind).uniqued() == StripKind.mainStereo.feeders)
    }

    @Test func mainLRShowsTheSwitchAndTheStripsOwnFader() {
        let main = StripID(.mainStereo)
        #expect(Catalog.feedOn(from: kick, to: main).address == "/ch/01/mix/st")
        #expect(Catalog.feedLevel(from: kick, to: main) == Catalog.fader(kick))
    }

    @Test func mainMShowsTheMonoSend() {
        let main = StripID(.mainMono)
        let bus = StripID(.bus, 3)
        #expect(Catalog.feedOn(from: bus, to: main).address == "/bus/03/mix/mono")
        #expect(Catalog.feedLevel(from: bus, to: main).address == "/bus/03/mix/mlevel")
        #expect(Catalog.feedLevel(from: bus, to: main).scale == .sendLevel, "level [-90…10, 161] like a send (p.26)")
    }

    @Test func aBusOrMatrixShowsTheSend() {
        let bus = StripID(.bus, 2)
        #expect(Catalog.feedOn(from: kick, to: bus) == Catalog.sendOn(from: kick, to: bus))
        #expect(Catalog.feedLevel(from: kick, to: bus) == Catalog.sendLevel(from: kick, to: bus))
    }

    /// On Main LR a row's level is the strip's fader, which moves its post-fader sends too, so the caption says so
    /// (mock F1, 2026-10-13). Elsewhere a row's level is a send, and the caption is the number alone.
    @Test func mainLRCaptionsNameTheFader() {
        let mirror = ConsoleMirror.preview()
        let main = StripID(.mainStereo)
        #expect(mirror.fedByCaption(of: .strip(kick, .full), on: main) == "Ch 1 · Fader")
        #expect(mirror.fedByCaption(of: .pair(StripID(.input, 9)), on: main) == "Ch 9-10 · Fader")
        #expect(mirror.fedByCaption(of: .strip(StripID(.input, 20), .full), on: main) == "Fader", "unnamed: title is Ch 20")
        #expect(mirror.fedByCaption(of: .strip(kick, .full), on: StripID(.mainMono)) == "Ch 1")
        #expect(mirror.fedByCaption(of: .strip(kick, .full), on: StripID(.bus, 1)) == "Ch 1")
        #expect(mirror.fedByCaption(of: .strip(StripID(.input, 20), .full), on: StripID(.bus, 1)) == nil)
    }

    @Test func openingFedByReadsEveryRow() {
        let mono = Catalog.tabAddresses(.fedBy, StripID(.mainMono), headamp: nil)
        #expect(mono.contains("/auxin/01/mix/mono"))
        #expect(mono.contains("/fxrtn/08/mix/mlevel"))
        #expect(mono.count == (32 + 8 + 8 + 16) * 2)
        #expect(Catalog.tabAddresses(.fedBy, StripID(.mainStereo), headamp: nil).contains("/bus/16/mix/st"))
    }

    /// Mono is off after a desk reset (assumed); the demo's kick and bass feed a mono sub at 0 dB.
    @Test func theDemoFeedsASub() {
        let values = DemoState.values()
        #expect(values["/ch/01/mix/mono"] == .int(1))
        #expect(values["/ch/08/mix/mono"] == .int(1))
        #expect(values["/ch/01/mix/mlevel"] == .float(0.75))
        #expect(values["/ch/02/mix/mono"] == .int(0))
        #expect(values["/ch/02/mix/mlevel"] == .float(0))
    }

    /// The desk links the mono level with fader and mute ("M/C level", p.46), so one side is written and the desk
    /// copies it.
    @Test func aLinkedPairsMonoLevelReachesBothSides() async throws {
        try await withLiveDesk { fake, mirror in
            let main = StripID(.mainMono)
            await openTab(.fedBy, of: main, in: mirror)
            let gtrL = StripID(.input, 9)

            mirror.set(Catalog.feedLevel(from: gtrL, to: main).address, .float(0.75))

            #expect(await eventually { fake.value(at: "/ch/10/mix/mlevel") == .float(0.75) })
        }
    }
}

extension Array where Element: Hashable {
    fileprivate func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

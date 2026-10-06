import FakeM32
import Testing

@testable import ThumbmixCore

@MainActor
struct StripEditTests {
    @Test func everyShownStripHasAnIconAddressThatIsSynced() {
        #expect(StripID(.dca, 1).icon == "/dca/1/config/icon")
        #expect(StripID(.mainStereo).icon == "/main/st/config/icon")
        let synced = Catalog.syncAddresses()
        #expect(StripKind.allCases.flatMap(StripID.all).allSatisfy { synced.contains($0.icon) })
        #expect(DemoState.values()["/ch/01/config/icon"] == .int(1))
    }

    @Test func iconsAreTheDesksSeventyFourInOrder() {
        #expect(ConsoleIcon.all.map(\.number) == Array(1...74))
        #expect(ConsoleIcon.all.allSatisfy { !$0.emoji.isEmpty && !$0.name.isEmpty })
        // Spot checks against the doc's appendix (p.138).
        #expect(ConsoleIcon.icon(1).name == "None")
        #expect(ConsoleIcon.icon(2).name == "Kick Back")
        #expect(ConsoleIcon.icon(41).name == "Male Vocal")
        #expect(ConsoleIcon.icon(74).name == "Smiley")
        #expect(ConsoleIcon.icon(99).number == 1, "unknown numbers fall back to None")
    }

    @Test func iconGroupsCoverEveryIconOnce() {
        let grouped = ConsoleIcon.groups.flatMap(\.icons).map(\.number)
        #expect(grouped.sorted() == Array(1...74))
    }

    @Test func namesAreCleanedToWhatTheDeskStores() {
        #expect(StripName.sanitized("Overhead Left Mic") == "Overhead Lef")
        #expect(StripName.sanitized("Café") == "Cafe")
        #expect(StripName.sanitized("Vox 🎤\n2") == "Vox 2")
        #expect(StripName.sanitized("  Bass  ") == "Bass")
    }

    @Test func colourIndexRoundTrips() {
        for index in 0...15 { #expect(ConsoleColor(index: index).index == index) }
        #expect(ConsoleColor(base: .green, inverted: true).index == 10)
    }

    @Test func editReachesTheConsole() async throws {
        let (fake, port) = try await startFake()
        defer { fake.stop() }
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port, timing: .fast))
        mirror.start()
        defer { mirror.stop() }
        #expect(await eventually(timeout: syncTimeout) { mirror.isLive })
        let drums = StripID(.dca, 1)

        mirror.edit(drums, name: "Kit", color: ConsoleColor(base: .green, inverted: false), icon: 11)

        #expect(
            await eventually {
                fake.value(at: drums.name) == .string("Kit") && fake.value(at: drums.color) == .int(2)
                    && fake.value(at: drums.icon) == .int(11)
            })
        #expect(mirror.name(drums) == "Kit")
    }
}

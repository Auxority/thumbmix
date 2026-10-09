import Foundation
import Testing

@testable import ThumbmixCore

/// Guards the String Catalog: a label shown in the app but missing from the catalog can never be translated.
struct LocalizationTests {
    private static let missing = "⟂missing⟂"

    private func isInCatalog(_ key: String) -> Bool {
        CoreStrings.bundle.localizedString(forKey: key, value: Self.missing, table: nil) != Self.missing
    }

    /// `scripts/strings.sh` adds new Core text as an empty entry, and SwiftPM drops those: the app would show the
    /// raw key. Read from the source catalog, since the built bundle has already dropped them.
    @Test func everyCoreCatalogEntryHasAnEnglishValue() throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().appendingPathComponent("../../Sources/ThumbmixCore/Resources/Localizable.xcstrings")
        let strings = try JSONDecoder().decode(StringCatalog.self, from: Data(contentsOf: catalog)).strings
        let empty = strings.filter { $0.value.localizations?["en"]?.stringUnit.value.isEmpty ?? true }.keys.sorted()
        #expect(empty.isEmpty, "no en value: \(empty)")
    }

    @Test func everyParameterLabelIsInTheCatalog() {
        let strip = StripID(.input, 1)
        var specs = [
            Catalog.fader(strip), Catalog.on(strip), Catalog.trim(strip), Catalog.headampGain(0),
            Catalog.headampPhantom(0), Catalog.eqOn(strip), Catalog.sendOn(from: strip, to: StripID(.bus, 1)),
        ]
        specs += [Catalog.pan(strip)].compactMap { $0 }
        specs += Catalog.gate(strip).all + Catalog.dynamics(strip).all + Catalog.eqBand(strip, 1).all
        specs += Catalog.delay(strip)?.all ?? []
        for spec in specs {
            #expect(isInCatalog(spec.label), "missing \(spec.label)")
        }
        for prompt in [Catalog.delay(strip)?.time, Catalog.headampGain(0)].compactMap({ $0?.resetPrompt }) {
            #expect(isInCatalog(prompt), "missing \(prompt)")
        }
    }

    @Test func formatsAndNamesAreInTheCatalog() {
        let keys =
            ["Bus %lld", "Ch %lld", "Aux %lld", "FX %lld", "Matrix %lld", "DCA %lld", "Main LR", "Main M", "On", "Off"]
            + ["Ch %lld-%lld", "Aux %lld-%lld", "FX %lld-%lld", "Bus %lld-%lld", "Matrix %lld-%lld"]
            + ["%@ stay separate.", "%@ stays separate.", "gain and delay", "EQ", "dynamics", "fader and mute"]
            + ChannelTab.allCases.map(\.titleKey) + StripGroup.allCases.map(\.titleKey)
        for key in keys {
            #expect(isInCatalog(key), "missing \(key)")
        }
    }

    @Test func englishReadsAsBefore() {
        #expect(Catalog.sendLevel(from: StripID(.input, 1), to: StripID(.bus, 3)).label == "Bus 3")
        #expect(StripID(.input, 7).defaultName == "Ch 7")
        #expect(ChannelTab.fedBy.title == "Fed by")
    }
}

/// The parts of an Xcode String Catalog (.xcstrings) the empty-entry check reads.
private struct StringCatalog: Decodable {
    struct Entry: Decodable {
        struct Localization: Decodable {
            struct Unit: Decodable { let value: String }
            let stringUnit: Unit
        }
        let localizations: [String: Localization]?
    }
    let strings: [String: Entry]
}

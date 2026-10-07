import Foundation
import Testing

@testable import ThumbmixCore

/// Guards the String Catalog: a label shown in the app but missing from the catalog can never be translated.
struct LocalizationTests {
    private static let missing = "⟂missing⟂"

    private func isInCatalog(_ key: String) -> Bool {
        CoreStrings.bundle.localizedString(forKey: key, value: Self.missing, table: nil) != Self.missing
    }

    @Test func everyParameterLabelIsInTheCatalog() {
        let strip = StripID(.input, 1)
        var specs = [
            Catalog.fader(strip), Catalog.on(strip), Catalog.trim(strip), Catalog.headampGain(0),
            Catalog.headampPhantom(0), Catalog.eqOn(strip), Catalog.sendOn(from: strip, toBus: 1),
        ]
        specs += [Catalog.pan(strip)].compactMap { $0 }
        specs += Catalog.gate(strip).all + Catalog.dynamics(strip).all + Catalog.eqBand(strip, 1).all
        for spec in specs {
            #expect(isInCatalog(spec.label), "missing \(spec.label)")
        }
    }

    @Test func formatsAndNamesAreInTheCatalog() {
        let keys =
            ["Bus %lld", "Ch %lld", "Aux %lld", "FX %lld", "DCA %lld", "Main LR", "Main M", "On", "Off"]
            + ["Ch %lld-%lld", "Aux %lld-%lld", "FX %lld-%lld", "Bus %lld-%lld"]
            + ChannelTab.allCases.map(\.titleKey) + StripGroup.allCases.map(\.titleKey)
        for key in keys {
            #expect(isInCatalog(key), "missing \(key)")
        }
    }

    @Test func englishReadsAsBefore() {
        #expect(Catalog.sendLevel(from: StripID(.input, 1), toBus: 3).label == "Bus 3")
        #expect(StripID(.input, 7).defaultName == "Ch 7")
        #expect(ChannelTab.fedBy.title == "Fed by")
    }
}

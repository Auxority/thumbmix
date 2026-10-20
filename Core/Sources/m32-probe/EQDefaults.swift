import ThumbmixCore

/// Section 11. Reset bands on an aux in or FX return writes an input's defaults; the doc gives no defaults for any
/// of them (TODO "EQ defaults").
@MainActor
func probeEQDefaults() async {
    print("\n== 11. EQ defaults: on the DESK, reset channel 1's, aux 1's and FX 1's EQ (or recall an empty scene), then press Enter.")
    _ = readLine()
    for strip in [StripID(.input, 1), StripID(.auxIn, 1), StripID(.fxReturn, 1)] {
        var bands: [String] = []
        for band in 1...strip.eqBandCount {
            let spec = Catalog.eqBand(strip, band).frequency
            let normalized = await ask(spec.address)?.arguments.first.flatMap(spec.scale.normalized(from:))
            bands.append(normalized.map { String(format: "%.0f Hz", spec.scale.value(fromNormalized: $0)) } ?? "?")
        }
        print(strip.defaultName + ": " + bands.joined(separator: ", "))
    }
    print("RESULT: the app resets all three to 125 Hz, 497 Hz, 1977 Hz and 10024 Hz. Different = fix Catalog.eqDefaults.")
}

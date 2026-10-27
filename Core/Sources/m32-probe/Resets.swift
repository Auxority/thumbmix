import ThumbmixCore

/// Section 20. Reset gate, Reset comp and Reset input write provisional values (`Catalog+Defaults`): the doc gives
/// no defaults, so the desk's own reset decides.
@MainActor
func probeResets() async {
    print("\n== 20. Resets: on the DESK, reset channel 1's gate, comp and input (or recall an empty scene),")
    print("then press Enter.")
    _ = readLine()
    let channel = StripID(.input, 1)
    let headamp: Int? =
        if case .int(let index)? = await ask(Catalog.headampIndex(forInput: 1))?.arguments.first, index >= 0 {
            Int(index)
        } else { nil }
    let defaults =
        Catalog.gateDefaults(channel) + Catalog.dynamicsDefaults(channel)
        + Catalog.inputDefaults(channel, headamp: headamp)
    var differences = 0
    for (spec, value) in defaults {
        let app = spec.scale.normalized(forValue: value)
        let desk = await ask(spec.address)?.arguments.first.flatMap(spec.scale.normalized(from:))
        let shown = desk.map { String(format: "%.2f", spec.scale.value(fromNormalized: $0)) } ?? "NO REPLY"
        let line = "\(spec.address): desk \(shown) app " + String(format: "%.2f", spec.scale.value(fromNormalized: app))
        if desk != app { differences += 1 }
        print(line + (desk == app ? "" : "  <- DIFFERS"))
    }
    if let headamp {
        let phantom = await ask(Catalog.headampPhantom(headamp).address).map(describe) ?? "NO REPLY"
        print("48V after the desk's reset: \(phantom) (the app's Reset input never touches it)")
    }
    print("RESULT: \(differences) of \(defaults.count) differ. Each DIFFERS line: put the desk's value in Catalog+Defaults.")
}

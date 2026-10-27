import ThumbmixCore

/// Section 20. Reset gate, Reset comp and Reset input write provisional values (`Catalog+Defaults`): the doc gives
/// no defaults, so the desk's own reset decides.
@MainActor
func probeResets() async {
    let channel = StripID(.input, 1)
    let headamp: Int? =
        if case .int(let index)? = await ask(Catalog.headampIndex(forInput: 1))?.arguments.first, index >= 0 {
            Int(index)
        } else { nil }
    let phantomBefore = await phantom(headamp)
    print("\n== 20. Resets: on the DESK, reset channel 1's gate, comp and input (or recall an empty scene),")
    print("then press Enter.")
    _ = readLine()
    let defaults =
        Catalog.gateDefaults(channel) + Catalog.dynamicsDefaults(channel)
        + Catalog.inputDefaults(channel, headamp: headamp)
    var differences = 0
    for (spec, value) in defaults {
        if await !deskMatches(spec, value) { differences += 1 }
    }
    print("48V before the desk's reset: \(phantomBefore), after: \(await phantom(headamp)) (the app's never touches it)")
    print("RESULT: \(differences) of \(defaults.count) differ. Each DIFFERS line: put the desk's value in Catalog+Defaults.")
}

/// Prints the desk's value for `spec` beside the app's, both on the desk's grid; false when they differ or the desk
/// didn't answer.
@MainActor
private func deskMatches(_ spec: ParamSpec, _ value: Double) async -> Bool {
    let app = spec.scale.normalized(forValue: value)
    let appText = String(format: "%.2f", spec.scale.value(fromNormalized: app))
    guard let desk = await ask(spec.address)?.arguments.first.flatMap(spec.scale.normalized(from:)) else {
        print("\(spec.address): NO REPLY (app \(appText))")
        return false
    }
    let matches = spec.scale.snap(desk) == app
    let deskText = String(format: "%.2f", spec.scale.value(fromNormalized: desk))
    print("\(spec.address): desk \(deskText) app \(appText)" + (matches ? "" : "  <- DIFFERS"))
    return matches
}

@MainActor
private func phantom(_ headamp: Int?) async -> String {
    guard let headamp else { return "no preamp" }
    return await ask(Catalog.headampPhantom(headamp).address).map(describe) ?? "NO REPLY"
}

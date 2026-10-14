import Foundation

/// What a gate or comp listens to (doc p.25, p.28-37): a key source on channels and buses, a filter on every one.
extension Catalog {
    /// The key filter's cuts and band-pass Qs, in the desk's terms (p.25: LC6 … HC12, then Q 1.0 … 10.0).
    public static let keyFilterTypes = [
        "LC6", "LC12", "HC6", "HC12", "BP Q 1.0", "BP Q 2.0", "BP Q 3.0", "BP Q 5.0", "BP Q 10",
    ]

    /// The strips `keysrc` 1-64 name, in order: In 1-32, Aux 1-6 and USB L/R (aux ins 7-8), FX 1L-4R (the eight FX
    /// returns), Bus 1-16. 0 is the strip itself.
    public static let keySources: [StripID] = [StripKind.input, .auxIn, .fxReturn, .bus].flatMap(StripID.all)

    public static func gateKey(_ strip: StripID) -> KeySpecs {
        key(strip.prefix + "/gate/", hasSource: strip.kind == .input)
    }

    public static func dynamicsKey(_ strip: StripID) -> KeySpecs {
        key(strip.prefix + "/dyn/", hasSource: [.input, .bus].contains(strip.kind))
    }

    /// `rawName` gives a strip's desk name, empty when unnamed: "Ch 3 · Kick", or "Ch 4". 0 reads "Self": the doc
    /// says OFF, the X32 manual "self", the strip keying itself (unchecked on the desk, TODO).
    public static func keySource(_ address: String, rawName: (StripID) -> String) -> ParamSpec {
        let names = keySources.map { strip in
            let name = rawName(strip)
            return name.isEmpty ? strip.defaultName : strip.defaultName + " · " + name
        }
        return ParamSpec(address, CoreStrings.text("Source"), .choice([CoreStrings.text("Self")] + names), .plain)
    }

    private static func key(_ prefix: String, hasSource: Bool) -> KeySpecs {
        KeySpecs(
            sourceAddress: hasSource ? prefix + "keysrc" : nil,
            filterOn: ParamSpec(prefix + "filter/on", CoreStrings.text("Filter"), .toggle, .plain),
            filterType: ParamSpec(prefix + "filter/type", CoreStrings.text("Type"), .choice(keyFilterTypes), .plain),
            filterFrequency: ParamSpec(
                prefix + "filter/f", CoreStrings.text("Filter freq"), .log(min: 20, max: 20_000, steps: 201), .hertz)
        )
    }
}

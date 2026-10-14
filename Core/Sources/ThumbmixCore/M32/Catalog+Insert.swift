import Foundation

/// A strip's insert (doc p.26 channels, p.31 buses, p.33 matrices, p.35-37 mains): on, position and the slot it
/// sends to. The slot is shown, not edited, until m32-probe tells what picking a slot another strip holds does
/// (2026-10-14).
extension Catalog {
    /// `insert/sel` 0…22 in the desk's order: OFF, FX1L, FX1R … FX8R, AUX1…AUX6.
    public static let insertSlots =
        ["OFF"] + (1...8).flatMap { ["FX\($0)L", "FX\($0)R"] } + (1...6).map { "AUX\($0)" }

    public static func insert(_ strip: StripID) -> InsertSpecs? {
        guard strip.hasInsert else { return nil }
        let p = strip.prefix + "/insert/"
        return InsertSpecs(
            on: ParamSpec(p + "on", CoreStrings.text("Insert"), .toggle, .plain),
            // PRE/POST sit before/after the EQ: the X32 quick start says so for buses, mains and matrices (Maillot
            // only says PRE/POST). Inputs are assumed the same until m32-probe confirms.
            position: ParamSpec(
                p + "pos", CoreStrings.text("Position"), .choice(["PRE", "POST"]), .plain,
                optionNames: [CoreStrings.text("Before EQ"), CoreStrings.text("After EQ")]),
            slot: ParamSpec(p + "sel", CoreStrings.text("Slot"), .choice(insertSlots), .plain))
    }

    /// The effect loaded in FX slot `fx` (1-8): an index into a list that differs for FX1-4 and FX5-8 (doc p.40).
    public static func fxType(_ fx: Int) -> String { "/fx/\(fx)/type" }

    public static let fxTypeAddresses = (1...8).map(fxType)
}

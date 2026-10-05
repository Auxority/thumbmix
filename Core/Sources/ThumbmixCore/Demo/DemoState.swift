/// A small band on inputs 1-14; everything else unnamed and pulled down, so "unused" has something to hide.
/// Shared by the fake console (tests, simulator) and SwiftUI previews, so both show the same desk.
public enum DemoState {
    private static let band: [(String, Int32)] = [
        ("Kick", 1), ("Snare", 1), ("Hi-hat", 1), ("Tom 1", 1), ("Tom 2", 1), ("OH L", 1), ("OH R", 1),
        ("Bass", 4), ("Gtr L", 3), ("Gtr R", 3), ("Keys L", 2), ("Keys R", 2), ("Vox 1", 5),
        ("Vox 2", 5),
    ]

    public static func values() -> [String: OSCArgument] {
        var state = Dictionary(uniqueKeysWithValues: Catalog.syncAddresses().map { ($0, defaultValue(for: $0)) })
        addBand(to: &state)
        addMonitors(to: &state)
        addReturnsDCAsAndMain(to: &state)
        return state
    }

    private static let unity = OSCArgument.float(ParamScale.fader.normalized(forValue: 0))

    /// Names a strip, colours it and puts its fader at 0 dB.
    private static func patch(_ strip: StripID, _ name: String, color: Int32, in state: inout [String: OSCArgument]) {
        state[strip.name] = .string(name)
        state[strip.color] = .int(color)
        state[strip.fader] = unity
    }

    private static func addBand(to state: inout [String: OSCArgument]) {
        for (offset, (name, color)) in band.enumerated() {
            let strip = StripID(.input, offset + 1)
            patch(strip, name, color: color, in: &state)
            // Drums on DCA 1, the band on DCA 2, vocals on DCA 3.
            if let dcaMask = strip.dcaMask { state[dcaMask] = .int(offset < 7 ? 1 : offset < 12 ? 2 : 4) }
        }
        // Patched but never named, as often happens mid-soundcheck: visible only while its fader is up.
        state[StripID(.input, 17).fader] = unity
        // Vox 2 shares Vox 1's preamp; inputs 15-16 read from an internal source.
        state[Catalog.headampIndex(forInput: 14)] = state[Catalog.headampIndex(forInput: 13)]
        state[Catalog.headampIndex(forInput: 15)] = .int(-1)
        state[Catalog.headampIndex(forInput: 16)] = .int(-1)
    }

    /// Monitor mixes 1-4, each fed by both vocals at 0 dB.
    private static func addMonitors(to state: inout [String: OSCArgument]) {
        for bus in 1...4 {
            patch(StripID(.bus, bus), "Mon \(bus)", color: 6, in: &state)
            for vox in [13, 14] { state[Catalog.sendLevel(from: StripID(.input, vox), toBus: bus).address] = .float(0.75) }
        }
    }

    private static func addReturnsDCAsAndMain(to state: inout [String: OSCArgument]) {
        patch(StripID(.fxReturn, 1), "Rev L", color: 5, in: &state)
        patch(StripID(.fxReturn, 2), "Rev R", color: 5, in: &state)
        for (number, name) in [(1, "Drums"), (2, "Band"), (3, "Vox")] { patch(StripID(.dca, number), name, color: 0, in: &state) }
        patch(StripID(.mainStereo), "LR", color: 0, in: &state)
    }

    /// First matching suffix wins; anything else is a continuous parameter at mid-travel.
    private static let defaultsBySuffix: [(suffix: String, value: OSCArgument)] = [
        ("/config/name", .string("")), ("/config/color", .int(0)), ("/config/icon", .int(1)), ("/grp/dca", .int(0)),
        ("/phantom", .int(0)), ("/hpon", .int(0)), ("/hpslope", .int(2)), ("/on", .int(1)), ("/type", .int(2)),
        ("/dyn/mode", .int(0)), ("/mode", .int(3)), ("/ratio", .int(3)),
        ("/fader", .float(0)), ("/level", .float(0)), ("/rta/source", .int(0)), ("/rta/pos", .int(0)),
    ]

    static func defaultValue(for address: String) -> OSCArgument {
        // Every input reads from the matching AES50-A preamp (headamps 32-63), like a DL32 patched 1:1.
        if address.hasPrefix("/-ha/") { return .int(Int32(32 + (Int(address.split(separator: "/")[1]) ?? 0))) }
        return defaultsBySuffix.first { address.hasSuffix($0.suffix) }?.value ?? .float(0.5)
    }
}

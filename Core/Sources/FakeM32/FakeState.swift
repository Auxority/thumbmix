import Foundation
import ThumbmixCore

/// A small band on inputs 1-14; everything else unnamed and pulled down, so "unused" has something to hide.
public enum FakeState {
    private static let band: [(String, Int32)] = [
        ("Kick", 1), ("Snare", 1), ("Hi-hat", 1), ("Tom 1", 1), ("Tom 2", 1), ("OH L", 1), ("OH R", 1),
        ("Bass", 4), ("Gtr L", 3), ("Gtr R", 3), ("Keys L", 2), ("Keys R", 2), ("Vox 1", 5), ("Vox 2", 5),
    ]

    public static func demo() -> [String: OSCArgument] {
        var state: [String: OSCArgument] = [:]
        for address in Catalog.syncAddresses() { state[address] = defaultValue(for: address) }
        let unity = OSCArgument.float(ParamScale.fader.normalized(forValue: 0))

        for (offset, (name, color)) in band.enumerated() {
            let strip = StripID(.input, offset + 1)
            state[strip.name] = .string(name)
            state[strip.color] = .int(color)
            state[strip.fader] = unity
            state[strip.dcaMask!] = .int(offset < 7 ? 1 : offset < 12 ? 2 : 4)
        }
        // Patched but never named, as often happens mid-soundcheck: visible only while its fader is up.
        state[StripID(.input, 17).fader] = unity
        // Vox 2 shares Vox 1's preamp; inputs 15-16 read from an internal source.
        state[Catalog.headampIndex(forInput: 14)] = state[Catalog.headampIndex(forInput: 13)]
        state[Catalog.headampIndex(forInput: 15)] = .int(-1)
        state[Catalog.headampIndex(forInput: 16)] = .int(-1)

        for bus in 1...4 {
            let strip = StripID(.bus, bus)
            state[strip.name] = .string("Mon \(bus)")
            state[strip.color] = .int(6)
            state[strip.fader] = unity
            for vox in [13, 14] { state[Catalog.sendLevel(from: StripID(.input, vox), toBus: bus).address] = .float(0.75) }
        }
        for (number, name) in [(1, "Rev L"), (2, "Rev R")] {
            let strip = StripID(.fxReturn, number)
            state[strip.name] = .string(name)
            state[strip.color] = .int(5)
            state[strip.fader] = unity
        }
        for (number, name) in [(1, "Drums"), (2, "Band"), (3, "Vox")] {
            let strip = StripID(.dca, number)
            state[strip.name] = .string(name)
            state[strip.fader] = unity
        }
        state[StripID(.mainStereo).name] = .string("LR")
        state[StripID(.mainStereo).fader] = unity
        return state
    }

    /// Slowly moving levels; gain-reduction slots hover below 1.0 (1.0 = no reduction).
    public static func meterValues(bank: String, time: Double) -> [Float] {
        let counts = ["/meters/0": 70, "/meters/1": 96, "/meters/2": 49, "/meters/5": 27]
        let reductionStart = ["/meters/1": 32, "/meters/2": 25]
        let count = counts[bank] ?? 4
        return (0..<count).map { index in
            let wave = Float(abs(sin(time * 1.5 + Double(index) * 0.7)))
            if let start = reductionStart[bank], index >= start { return 1 - 0.4 * wave }
            return 0.02 + 0.3 * wave
        }
    }

    static func defaultValue(for address: String) -> OSCArgument {
        if address.hasSuffix("/config/name") { return .string("") }
        if address.hasSuffix("/config/color") || address.hasSuffix("/grp/dca") { return .int(0) }
        if address.hasPrefix("/-ha/") {
            let input = Int(address.split(separator: "/")[1]) ?? 0
            return .int(Int32(32 + input))
        }
        if address.hasSuffix("/phantom") { return .int(0) }
        if address.hasSuffix("/on") { return .int(1) }
        if address.hasSuffix("/type") { return .int(2) }
        if address.hasSuffix("/mode") { return .int(3) }
        if address.hasSuffix("/ratio") { return .int(3) }
        if address.hasSuffix("/fader") || address.hasSuffix("/level") { return .float(0) }
        return .float(0.5)
    }
}

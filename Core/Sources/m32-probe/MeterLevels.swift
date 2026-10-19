import Foundation
import ThumbmixCore

/// One slot of one meter bank: `request` is what /meters takes (doc p.16-19), `slot` the 0-based place in its blob.
struct MeterTap {
    let label: String
    let request: [OSCArgument]
    let slot: Int

    init(_ label: String, _ request: [OSCArgument], _ slot: Int) {
        self.label = label
        self.request = request
        self.slot = slot
    }

    var bank: String {
        guard case .string(let bank)? = request.first else { return "" }
        return bank
    }
}

/// One request per bank: a reply names only its bank, so two requests for one bank couldn't be told apart.
func uniqueRequests(_ taps: [MeterTap]) -> [[OSCArgument]] {
    var seen = Set<String>()
    return taps.filter { seen.insert($0.bank).inserted }.map(\.request)
}

/// Each slot of every requested bank, averaged (or its peak) over `seconds`, in the desk's linear scale: 1 = 0 dBFS,
/// up to 8 = +18 dBFS (doc p.16). Keyed by bank; a bank that didn't answer is missing.
@MainActor
func slotAverages(_ requests: [[OSCArgument]], seconds: Int, peak: Bool = false) async -> [String: [Float]] {
    recorder.clear()
    for request in requests { transport.send(OSCMessage("/meters", request)) }
    try? await Task.sleep(for: .seconds(seconds))
    var averages: [String: [Float]] = [:]
    for case .string(let bank)? in requests.map(\.first) {
        let blobs = recorder.messages.filter { $0.address == bank }.compactMap { message -> [Float]? in
            guard case .blob(let blob)? = message.arguments.first else { return nil }
            return MeterBlob.floats(from: blob)
        }
        guard let count = blobs.map(\.count).min(), count > 0 else { continue }
        averages[bank] = (0..<count).map { slot in
            let values = blobs.map { $0[slot] }
            return peak ? values.max() ?? 0 : values.reduce(0, +) / Float(values.count)
        }
    }
    return averages
}

/// Each tap's average (or peak) over `seconds`, linear; nil when any of their banks didn't answer.
@MainActor
func tapLevels(_ taps: [MeterTap], seconds: Int, peak: Bool = false) async -> [Float]? {
    let banks = await slotAverages(uniqueRequests(taps), seconds: seconds, peak: peak)
    let levels = taps.compactMap { banks[$0.bank]?.dropFirst($0.slot).first }
    return levels.count == taps.count ? levels : nil
}

/// Each tap's level after the engineer sets `first`, then `second`; second minus first per tap, in dB.
@MainActor
func compareTaps(_ taps: [MeterTap], _ first: String, _ second: String) async -> [Float]? {
    var levels: [[Float]] = []
    for step in [first, second] {
        print("  On the DESK: \(step) (10 seconds), then hands off while it measures...")
        try? await Task.sleep(for: .seconds(10))
        guard let reading = await tapLevels(taps, seconds: 4)?.map(decibels) else {
            print("  meters: NO REPLY")
            return nil
        }
        print("  " + zip(taps, reading).map { $0.label + String(format: " %.1f dB", $1) }.joined(separator: ", "))
        levels.append(reading)
    }
    return zip(levels[1], levels[0]).map { $0 - $1 }
}

func decibels(_ level: Float) -> Float { 20 * log10(max(level, 1e-6)) }

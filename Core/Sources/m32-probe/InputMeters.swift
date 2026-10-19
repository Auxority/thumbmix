import Foundation
import ThumbmixCore

/// Section 15. The gain helper (TODO.md) sets a preamp from a channel's meter, assuming a post-preamp level about
/// every 50 ms (p.16), raw rather than held, a gain change seen within 200 ms and a clip at 0 dBFS. The doc lists
/// channel meters in five banks without saying where each taps, so the probe times them all at once.
@MainActor
func probeInputMeters() async {
    let strip = StripID(.input, 1)
    print("\n== 15. Input meters. Setup: channel 1 fed by a local preamp (AN), a steady source into it (pink noise")
    print("or a held tone from a phone, not a song), its fader down or the PA muted: 15d gets loud.")
    print(await preampLine(strip))
    guard case .int(let headamp)? = await ask(Catalog.headampIndex(strip) ?? "")?.arguments.first,
        (0...127).contains(headamp)
    else {
        print("RESULT: channel 1 has no preamp. Route it from a local input and run again.")
        return
    }
    await probeMeterStreams()
    await probeGainStep(Catalog.headampGain(Int(headamp)))
    await probeRelease()
    await probeClip()
}

/// Channel 1 in every bank the doc lists it in (p.17-18).
private let inputTaps = [
    MeterTap("/meters/0 (METERS page)", [.string("/meters/0")], 0),
    MeterTap("/meters/1 (channel page, the app's)", [.string("/meters/1")], 0),
    MeterTap("/meters/4 (in/out page)", [.string("/meters/4")], 0),
    MeterTap("/meters/5 (surface VU)", [.string("/meters/5"), .int(0), .int(0)], 0),
    MeterTap("/meters/6 post gain/trim", [.string("/meters/6"), .int(0)], 0),
    MeterTap("/meters/6 post-fade", [.string("/meters/6"), .int(0)], 3),
    MeterTap("/meters/13 (METERS page)", [.string("/meters/13")], 0),
]

private struct Reading {
    let time: ContinuousClock.Instant
    let level: Float
    var decibels: Float { m32_probe.decibels(level) }
}

/// Everything the desk sends for `seconds`, each with its arrival time; /xremote and the meter requests are renewed
/// before they lapse (10 s, p.16).
@MainActor
private func record(seconds: Int) async -> [Arrival] {
    recorder.clear()
    for elapsed in 0..<seconds {
        if elapsed % 9 == 0 {
            transport.send(OSCMessage("/xremote"))
            for request in uniqueRequests(inputTaps) { transport.send(OSCMessage("/meters", request)) }
        }
        try? await Task.sleep(for: .seconds(1))
    }
    return recorder.arrivals
}

private func readings(_ tap: MeterTap, in arrivals: [Arrival]) -> [Reading] {
    arrivals.compactMap { arrival in
        guard arrival.message.address == tap.bank, case .blob(let blob)? = arrival.message.arguments.first,
            let level = MeterBlob.floats(from: blob).dropFirst(tap.slot).first
        else { return nil }
        return Reading(time: arrival.time, level: level)
    }
}

/// The energy average in dB, as the gain helper's level is.
private func average(_ readings: [Reading]) -> Float {
    decibels(readings.map(\.level).reduce(0, +) / Float(max(readings.count, 1)))
}

private func milliseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
}

private func printEachTap(_ arrivals: [Arrival], _ summary: ([Reading]) -> String) {
    for tap in inputTaps { print("  " + tap.label + ": " + summary(readings(tap, in: arrivals))) }
}

@MainActor
private func probeMeterStreams() async {
    print("\n15a. Hands off for 5 seconds while the probe listens...")
    printEachTap(await record(seconds: 5)) { readings in
        guard readings.count > 1 else { return "NO REPLY" }
        let gaps = zip(readings.dropFirst(), readings).map { milliseconds($0.time - $1.time) }.sorted()
        return String(
            format: "every %.0f ms (%.0f-%.0f), average %.1f dB, peak %.1f dB", gaps[gaps.count / 2], gaps[0],
            gaps[gaps.count - 1], average(readings), readings.map(\.decibels).max() ?? 0)
    }
    print("RESULT: \"every\" = how often the desk sends it (median gap; the doc says about 50 ms). Taps with the same")
    print("levels likely meter the same point.")
}

@MainActor
private func probeGainStep(_ gain: ParamSpec) async {
    print("\n15b. On the DESK, after about 3 seconds, turn channel 1's gain down about 10 dB in one quick twist, then")
    print("hands off (12 seconds)...")
    let arrivals = await record(seconds: 12)
    let pushes = arrivals.filter { $0.message.address == gain.address }
    guard let first = pushes.first, let last = pushes.last else {
        print("  \(gain.address): NO pushes. The desk didn't send the gain change, so nothing can be timed.")
        return
    }
    let decibelsText = { (arrival: Arrival) in
        arrival.message.arguments.first.flatMap(gain.scale.normalized(from:)).map {
            String(format: "%+.1f dB", gain.scale.value(fromNormalized: $0))
        } ?? "?"
    }
    print(
        "  gain \(decibelsText(first)) -> \(decibelsText(last)), \(pushes.count) pushes over "
            + String(format: "%.0f ms", milliseconds(last.time - first.time)))
    printEachTap(arrivals) { stepSummary($0, first: first.time, last: last.time) }
    print("RESULT: a change close to the gain's = that tap is after the preamp (the one the gain helper needs); about 0")
    print("= before it. \"moved\" = how long after the first gain push the meter moved 2 dB (the helper skips 200 ms);")
    print("\"settled\" = after the last push, when it stayed within 3 dB of its new level. Turn the gain back.")
}

private func stepSummary(_ readings: [Reading], first: ContinuousClock.Instant, last: ContinuousClock.Instant) -> String {
    guard let end = readings.last?.time else { return "NO REPLY" }
    let before = readings.filter { $0.time < first && first - $0.time < .seconds(1) }
    let after = readings.filter { end - $0.time < .seconds(1) }
    guard !before.isEmpty, end - last > .seconds(2) else { return "too few readings around the twist" }
    let (from, to) = (average(before), average(after))
    let moved = readings.first { $0.time >= first && abs($0.decibels - from) >= 2 }
    let lastOut = readings.lastIndex { abs($0.decibels - to) > 3 }
    let settled = lastOut.map { readings[min($0 + 1, readings.count - 1)].time } ?? first
    return String(format: "%.1f -> %.1f dB (%+.1f)", from, to, to - from)
        + (moved.map { String(format: ", moved %.0f ms", milliseconds($0.time - first)) } ?? ", never moved 2 dB")
        + String(format: ", settled %.0f ms", max(0, milliseconds(settled - last)))
}

@MainActor
private func probeRelease() async {
    print("\n15c. Keep the source playing, then after about 3 seconds stop it dead (stop the player, no fade) (8 seconds)...")
    printEachTap(await record(seconds: 8), fallSummary)
    print("RESULT: 30 dB down in one or two readings (~100 ms) = raw levels; a steady fall = a release (its dB/s);")
    print("the same value for several readings before the fall = a peak hold.")
}

private func fallSummary(_ readings: [Reading]) -> String {
    guard let start = readings.first?.time else { return "NO REPLY" }
    let steady = average(readings.filter { $0.time - start < .seconds(1) })
    guard let drop = readings.firstIndex(where: { $0.decibels < steady - 10 }),
        let onset = readings[..<drop].lastIndex(where: { $0.decibels >= steady - 3 })
    else { return "no stop seen" }
    let gone = readings[onset...].first { $0.decibels < steady - 30 }
    let fall = gone.map { String(format: "30 dB down in %.0f ms", milliseconds($0.time - readings[onset].time)) }
    let shape = readings[onset...].prefix(16).map { String(format: "%.0f", $0.decibels - steady) }
    return (fall ?? "never 30 dB down") + "; each reading vs steady (dB): " + shape.joined(separator: " ")
}

@MainActor
private func probeClip() async {
    print("\n15d. Raise channel 1's gain until the desk's clip light comes on, hold it there 3 seconds, then turn it")
    print("back (12 seconds)...")
    printEachTap(await record(seconds: 12)) { readings in
        guard let peak = readings.map(\.level).max() else { return "NO REPLY" }
        return String(format: "peak %.3f (%+.1f dBFS)", peak, decibels(peak))
    }
    print("RESULT: about 1.000 = a clip shows at 0 dBFS (the gain helper's clip rule); above = the meter goes past it")
    print("(up to 8.0 = +18 dBFS, p.16); well below 1.000 = it misses clips, and the helper needs another sign.")
}

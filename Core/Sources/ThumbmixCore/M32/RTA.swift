import Foundation

/// The desk's real-time analyser. It measures one source at a time for the whole desk, so the app
/// borrows it while a channel's EQ is open and puts the desk's own setting back afterwards.
public enum RTA {
    /// int: 0 none, 1 Monitor, 2-33 Ch01-32, 34-41 Aux1-8, 42-49 FX1L-FX4R, 50-65 Bus01-16,
    /// 66-71 Mtx1-6, 72 Main, 73 Mono (doc p.58).
    public static let source = "/-prefs/rta/source"
    /// 0 = before the EQ, 1 = after it (doc p.58).
    public static let position = "/-prefs/rta/pos"
    public static let afterEQ: Int32 = 1

    /// 100 bands, 20 Hz to 18.66 kHz, every 50 ms (doc p.19).
    public static let bank = "/meters/15"
    public static let subscription = OSCMessage("/meters", [.string(bank)])
    public static let bandCount = 100

    /// The doc lists the bands as log-spaced from 20 Hz to 18.66 kHz; this spacing matches its table within 2%.
    public static func bandFrequency(_ index: Int) -> Double {
        20 * pow(18_660 / 20, Double(index) / Double(bandCount - 1))
    }
}

extension StripID {
    /// The `/-prefs/rta/source` value that analyses this strip; nil for DCAs, which carry no audio.
    public var rtaSource: Int32? {
        switch kind {
        case .input: Int32(1 + number)
        case .auxIn: Int32(33 + number)
        case .fxReturn: Int32(41 + number)
        case .bus: Int32(49 + number)
        case .matrix: Int32(65 + number)
        case .mainStereo: 72
        case .mainMono: 73
        case .dca: nil
        }
    }
}

extension MeterBlob {
    /// `/meters/15` packs 100 little-endian Int16 values into 50 words after the count (doc p.19);
    /// each is dB * 256, so the range is -128...0 dB and 0 means clipping.
    public static func rtaDecibels(from blob: Data) -> [Float] {
        let bytes = [UInt8](blob)
        guard bytes.count >= 4 else { return [] }
        let words = Int(UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24)
        let count = Swift.min(words * 2, (bytes.count - 4) / 2)
        return (0..<count).map { index in
            let low = UInt16(bytes[4 + index * 2])
            let high = UInt16(bytes[5 + index * 2])
            return Float(Int16(bitPattern: low | high << 8)) / 256
        }
    }

    /// The fake console's side of `rtaDecibels`.
    public static func encodeRTA(_ decibels: [Float]) -> Data {
        let words = (decibels.count + 1) / 2
        var out = Data((0..<4).map { UInt8(truncatingIfNeeded: words >> ($0 * 8)) })
        for value in decibels {
            let raw = UInt16(bitPattern: Int16(max(min(value, 0), -128) * 256))
            out.append(contentsOf: [UInt8(truncatingIfNeeded: raw), UInt8(truncatingIfNeeded: raw >> 8)])
        }
        return out
    }
}

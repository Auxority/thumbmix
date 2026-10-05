public struct MeterReading: Equatable, Sendable {
    public var level: Float
    public var gateGain: Float?
    public var dynamicsGain: Float?

    public init(level: Float, gateGain: Float? = nil, dynamicsGain: Float? = nil) {
        self.level = level
        self.gateGain = gateGain
        self.dynamicsGain = dynamicsGain
    }
}

/// The meter banks Thumbmix subscribes to and where each strip sits in them (doc p.17-19).
public enum MeterBanks {
    public static let subscriptions: [OSCMessage] = [
        OSCMessage("/meters", [.string("/meters/0")]),
        OSCMessage("/meters", [.string("/meters/1")]),
        OSCMessage("/meters", [.string("/meters/2")]),
        OSCMessage("/meters", [.string("/meters/5"), .int(0), .int(0)]),
    ]

    /// Unknown banks and blobs shorter than their layout yield nothing.
    public static func readings(address: String, values: [Float]) -> [StripID: MeterReading] {
        guard let bank = layouts[address], values.count >= bank.minimumCount else { return [:] }
        return bank.read(values)
    }

    private struct Layout: Sendable {
        let minimumCount: Int
        let read: @Sendable ([Float]) -> [StripID: MeterReading]
    }

    private static let layouts: [String: Layout] = [
        "/meters/0": Layout(minimumCount: 48, read: auxAndFXReturns),
        "/meters/1": Layout(minimumCount: 96, read: inputs),
        "/meters/2": Layout(minimumCount: 49, read: busesAndMains),
        "/meters/5": Layout(minimumCount: 24, read: dcas),
    ]

    private static func auxAndFXReturns(_ v: [Float]) -> [StripID: MeterReading] {
        let aux = (0..<8).map { (StripID(.auxIn, $0 + 1), MeterReading(level: v[32 + $0])) }
        let fx = (0..<8).map { (StripID(.fxReturn, $0 + 1), MeterReading(level: v[40 + $0])) }
        return Dictionary(uniqueKeysWithValues: aux + fx)
    }

    private static func inputs(_ v: [Float]) -> [StripID: MeterReading] {
        Dictionary(
            uniqueKeysWithValues: (0..<32).map {
                (StripID(.input, $0 + 1), MeterReading(level: v[$0], gateGain: v[32 + $0], dynamicsGain: v[64 + $0]))
            })
    }

    private static func busesAndMains(_ v: [Float]) -> [StripID: MeterReading] {
        var readings = Dictionary(
            uniqueKeysWithValues: (0..<16).map {
                (StripID(.bus, $0 + 1), MeterReading(level: v[$0], dynamicsGain: v[25 + $0]))
            })
        readings[StripID(.mainStereo)] = MeterReading(level: max(v[22], v[23]), dynamicsGain: v[47])
        readings[StripID(.mainMono)] = MeterReading(level: v[24], dynamicsGain: v[48])
        return readings
    }

    /// The DCA slots are inferred from the doc's list order; m32-probe section 5 checks this.
    private static func dcas(_ v: [Float]) -> [StripID: MeterReading] {
        Dictionary(uniqueKeysWithValues: (0..<8).map { (StripID(.dca, $0 + 1), MeterReading(level: v[16 + $0])) })
    }
}

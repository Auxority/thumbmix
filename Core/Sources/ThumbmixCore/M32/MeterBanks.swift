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

    public static func readings(address: String, values v: [Float]) -> [StripID: MeterReading] {
        var readings: [StripID: MeterReading] = [:]
        switch address {
        case "/meters/0" where v.count >= 48:
            for i in 0..<8 {
                readings[StripID(.auxIn, i + 1)] = MeterReading(level: v[32 + i])
                readings[StripID(.fxReturn, i + 1)] = MeterReading(level: v[40 + i])
            }
        case "/meters/1" where v.count >= 96:
            for i in 0..<32 {
                readings[StripID(.input, i + 1)] = MeterReading(
                    level: v[i], gateGain: v[32 + i], dynamicsGain: v[64 + i])
            }
        case "/meters/2" where v.count >= 49:
            for i in 0..<16 {
                readings[StripID(.bus, i + 1)] = MeterReading(level: v[i], dynamicsGain: v[25 + i])
            }
            readings[StripID(.mainStereo)] = MeterReading(level: max(v[22], v[23]), dynamicsGain: v[47])
            readings[StripID(.mainMono)] = MeterReading(level: v[24], dynamicsGain: v[48])
        case "/meters/5" where v.count >= 24:
            // The DCA slots are inferred from the doc's list order; m32-probe section 5 checks this.
            for i in 0..<8 { readings[StripID(.dca, i + 1)] = MeterReading(level: v[16 + i]) }
        default:
            break
        }
        return readings
    }
}

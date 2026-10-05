import Foundation

/// Meter drawing: -60...0 dBFS fills the bar; console headroom above 0 dBFS is clamped.
public enum MeterScale {
    public static let floorDecibels = -60.0

    public static func decibels(_ linear: Float) -> Double {
        linear > 0 ? 20 * log10(Double(linear)) : -.infinity
    }

    public static func fraction(decibels: Double) -> Double {
        Swift.min(Swift.max((decibels - floorDecibels) / -floorDecibels, 0), 1)
    }

    public static func fraction(linear: Float) -> Double {
        fraction(decibels: decibels(linear))
    }

    /// How many dB a gate or compressor is pulling down (positive number), capped at the meter floor.
    public static func reductionDecibels(gain: Float) -> Double {
        gain >= 1 ? 0 : Swift.min(-decibels(gain), -floorDecibels)
    }
}

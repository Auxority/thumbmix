import Foundation

/// The EQ graph's x axis: log 20 Hz-20 kHz over 0...1, the same law as the band frequency parameter. The RTA glow
/// lines up under the bands with it.
public enum EQAxis {
    public static func position(hertz: Double) -> Double { log(hertz / 20) / log(1000) }

    public static func hertz(at position: Double) -> Double { 20 * pow(1000, position) }
}

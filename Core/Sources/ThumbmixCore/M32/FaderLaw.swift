/// The console's 4-segment fader taper (Maillot protocol doc p.131): 0.75 = 0 dB, 1.0 = +10 dB, 0 = -∞.
public enum FaderLaw {
    public static func decibels(fromWire wire: Double) -> Double {
        switch wire {
        case ...0: -.infinity
        case 0.5...: wire * 40 - 30
        case 0.25...: wire * 80 - 50
        case 0.0625...: wire * 160 - 70
        default: wire * 480 - 90
        }
    }

    public static func wire(fromDecibels decibels: Double) -> Double {
        switch decibels {
        case ..<(-90): 0
        case ..<(-60): (decibels + 90) / 480
        case ..<(-30): (decibels + 70) / 160
        case ..<(-10): (decibels + 50) / 80
        default: Swift.min((decibels + 30) / 40, 1)
        }
    }
}

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

    /// The dB the desk itself shows for a fader position, to 0.1 dB.
    public static func shownDecibels(fromWire wire: Double) -> Double {
        let step = Int((Swift.min(Swift.max(wire, 0), 1) * 1023).rounded())
        return deskExceptions[step] ?? (decibels(fromWire: wire) * 10).rounded() / 10
    }

    /// Steps where the desk's own table (doc p.145) differs from the law rounded to 0.1 dB: it reads 0 from
    /// −0.09 to +0.07 dB (a detent at unity), and rounds two steps the other way. m32-probe section 8 checks these.
    private static let deskExceptions: [Int: Double] = [
        342: -23.2, 547: -8.7, 765: 0, 766: 0, 767: 0, 768: 0, 769: 0,
    ]

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

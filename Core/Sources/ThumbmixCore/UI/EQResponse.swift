import Foundation

public struct EQBandState: Equatable, Sendable {
    public let typeIndex: Int
    public let frequency: Double
    public let gain: Double
    public let q: Double

    public init(typeIndex: Int, frequency: Double, gain: Double, q: Double) {
        self.typeIndex = typeIndex
        self.frequency = frequency
        self.gain = gain
        self.q = q
    }
}

/// RBJ-cookbook biquads at 48 kHz. An approximation of the console's curves: good enough to see
/// what a band does, not a measurement.
public enum EQResponse {
    private static let sampleRate = 48_000.0

    public static func decibels(at frequency: Double, bands: [EQBandState]) -> Double {
        bands.reduce(0) { $0 + decibels(of: $1, at: frequency) }
    }

    private static func decibels(of band: EQBandState, at frequency: Double) -> Double {
        guard let c = coefficients(band) else { return 0 }
        let w = 2 * Double.pi * frequency / sampleRate
        let numeratorReal = c.b0 + c.b1 * cos(w) + c.b2 * cos(2 * w)
        let numeratorImaginary = -(c.b1 * sin(w) + c.b2 * sin(2 * w))
        let denominatorReal = c.a0 + c.a1 * cos(w) + c.a2 * cos(2 * w)
        let denominatorImaginary = -(c.a1 * sin(w) + c.a2 * sin(2 * w))
        let power = (numeratorReal * numeratorReal + numeratorImaginary * numeratorImaginary)
            / (denominatorReal * denominatorReal + denominatorImaginary * denominatorImaginary)
        return 10 * log10(power)
    }

    private struct Coefficients {
        let b0, b1, b2, a0, a1, a2: Double
    }

    private static func coefficients(_ band: EQBandState) -> Coefficients? {
        let w0 = 2 * Double.pi * band.frequency / sampleRate
        let cosine = cos(w0)
        let a = pow(10, band.gain / 40)
        let alpha = sin(w0) / (2 * band.q)
        let cutAlpha = sin(w0) / (2 * 0.707)
        let shelf = 2 * sqrt(a) * alpha
        switch band.typeIndex {
        case 0: // LCut: 12 dB/oct high-pass
            return Coefficients(b0: (1 + cosine) / 2, b1: -(1 + cosine), b2: (1 + cosine) / 2,
                                a0: 1 + cutAlpha, a1: -2 * cosine, a2: 1 - cutAlpha)
        case 1: // LShv
            return Coefficients(b0: a * ((a + 1) - (a - 1) * cosine + shelf), b1: 2 * a * ((a - 1) - (a + 1) * cosine),
                                b2: a * ((a + 1) - (a - 1) * cosine - shelf), a0: (a + 1) + (a - 1) * cosine + shelf,
                                a1: -2 * ((a - 1) + (a + 1) * cosine), a2: (a + 1) + (a - 1) * cosine - shelf)
        case 2, 3: // PEQ, VEQ
            return Coefficients(b0: 1 + alpha * a, b1: -2 * cosine, b2: 1 - alpha * a,
                                a0: 1 + alpha / a, a1: -2 * cosine, a2: 1 - alpha / a)
        case 4: // HShv
            return Coefficients(b0: a * ((a + 1) + (a - 1) * cosine + shelf), b1: -2 * a * ((a - 1) + (a + 1) * cosine),
                                b2: a * ((a + 1) + (a - 1) * cosine - shelf), a0: (a + 1) - (a - 1) * cosine + shelf,
                                a1: 2 * ((a - 1) - (a + 1) * cosine), a2: (a + 1) - (a - 1) * cosine - shelf)
        case 5: // HCut: 12 dB/oct low-pass
            return Coefficients(b0: (1 - cosine) / 2, b1: 1 - cosine, b2: (1 - cosine) / 2,
                                a0: 1 + cutAlpha, a1: -2 * cosine, a2: 1 - cutAlpha)
        default: // Main-bus crossover types: drawn flat; the band rows still show their numbers.
            return nil
        }
    }
}

public extension ConsoleMirror {
    /// Empty when the strip's EQ is off, so the graph draws flat.
    func eqBands(_ strip: StripID) -> [EQBandState] {
        guard strip.eqBandCount > 0, cell(Catalog.eqOn(strip).address).argument == .int(1) else { return [] }
        return (1...strip.eqBandCount).map { band in
            let specs = Catalog.eqBand(strip, band)
            return EQBandState(
                typeIndex: Int(specs.type.scale.value(fromNormalized: normalized(specs.type) ?? 0)),
                frequency: specs.frequency.scale.value(fromNormalized: normalized(specs.frequency) ?? 0.5),
                gain: specs.gain.scale.value(fromNormalized: normalized(specs.gain) ?? 0.5),
                q: specs.q.scale.value(fromNormalized: normalized(specs.q) ?? 0.5)
            )
        }
    }
}

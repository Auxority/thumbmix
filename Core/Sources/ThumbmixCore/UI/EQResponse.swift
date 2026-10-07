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
        let power =
            (numeratorReal * numeratorReal + numeratorImaginary * numeratorImaginary)
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
        case 0:  // LCut: 12 dB/oct high-pass
            return Coefficients(
                b0: (1 + cosine) / 2, b1: -(1 + cosine), b2: (1 + cosine) / 2,
                a0: 1 + cutAlpha, a1: -2 * cosine, a2: 1 - cutAlpha)
        case 1:  // LShv
            return Coefficients(
                b0: a * ((a + 1) - (a - 1) * cosine + shelf), b1: 2 * a * ((a - 1) - (a + 1) * cosine),
                b2: a * ((a + 1) - (a - 1) * cosine - shelf), a0: (a + 1) + (a - 1) * cosine + shelf,
                a1: -2 * ((a - 1) + (a + 1) * cosine), a2: (a + 1) + (a - 1) * cosine - shelf)
        case 2, 3:  // PEQ, VEQ
            return Coefficients(
                b0: 1 + alpha * a, b1: -2 * cosine, b2: 1 - alpha * a,
                a0: 1 + alpha / a, a1: -2 * cosine, a2: 1 - alpha / a)
        case 4:  // HShv
            return Coefficients(
                b0: a * ((a + 1) + (a - 1) * cosine + shelf), b1: -2 * a * ((a - 1) + (a + 1) * cosine),
                b2: a * ((a + 1) + (a - 1) * cosine - shelf), a0: (a + 1) - (a - 1) * cosine + shelf,
                a1: 2 * ((a - 1) - (a + 1) * cosine), a2: (a + 1) - (a - 1) * cosine - shelf)
        case 5:  // HCut: 12 dB/oct low-pass
            return Coefficients(
                b0: (1 - cosine) / 2, b1: 1 - cosine, b2: (1 - cosine) / 2,
                a0: 1 + cutAlpha, a1: -2 * cosine, a2: 1 - cutAlpha)
        default:  // Main-bus crossover types: drawn flat; the band rows still show their numbers.
            return nil
        }
    }
}

/// The channel low cut as a Butterworth high-pass of order 2, 3 or 4 (12/18/24 dB/oct): -3 dB at the
/// cutoff. Like `EQResponse`, a picture of what the filter does, not a measurement of the desk.
public struct LowCutState: Equatable, Sendable {
    public let frequency: Double
    public let slopeIndex: Int

    public init(frequency: Double, slopeIndex: Int) {
        self.frequency = frequency
        self.slopeIndex = slopeIndex
    }

    public func decibels(at hertz: Double) -> Double {
        let order = Double(slopeIndex + 2)
        return -10 * log10(1 + pow(frequency / hertz, 2 * order))
    }
}

/// A strip's EQ and low cut from raw desk values, wherever they are kept: the mirror's cells for the graph, the
/// fake console's state for the offline demo's "after EQ" spectrum.
public enum EQReading {
    /// nil when the strip has no low cut, it is off, or its values were never read: no cut is drawn.
    public static func lowCut(_ strip: StripID, value: (String) -> OSCArgument?) -> LowCutState? {
        guard let specs = Catalog.lowCut(strip), value(specs.on.address) == .int(1),
            let frequency = normalized(specs.frequency, value), let slope = normalized(specs.slope, value)
        else { return nil }
        return LowCutState(
            frequency: specs.frequency.scale.value(fromNormalized: frequency),
            slopeIndex: Int(specs.slope.scale.value(fromNormalized: slope)))
    }

    /// Empty when the strip's EQ is off, so the curve is flat.
    public static func bands(_ strip: StripID, value: (String) -> OSCArgument?) -> [EQBandState] {
        guard strip.eqBandCount > 0, value(Catalog.eqOn(strip).address) == .int(1) else { return [] }
        func real(_ spec: ParamSpec, _ fallback: Float) -> Double {
            spec.scale.value(fromNormalized: normalized(spec, value) ?? fallback)
        }
        return (1...strip.eqBandCount).map { band in
            let specs = Catalog.eqBand(strip, band)
            return EQBandState(
                typeIndex: Int(real(specs.type, 0)), frequency: real(specs.frequency, 0.5),
                gain: real(specs.gain, 0.5), q: real(specs.q, 0.5))
        }
    }

    /// The curve's level at `hertz`: the bands plus the low cut.
    public static func decibels(at hertz: Double, bands: [EQBandState], lowCut: LowCutState?) -> Double {
        EQResponse.decibels(at: hertz, bands: bands) + (lowCut?.decibels(at: hertz) ?? 0)
    }

    private static func normalized(_ spec: ParamSpec, _ value: (String) -> OSCArgument?) -> Float? {
        value(spec.address).flatMap(spec.scale.normalized(from:))
    }
}

extension ConsoleMirror {
    /// nil when the strip has no low cut, it is off, or its values were never read: the graph draws no cut.
    public func lowCut(_ strip: StripID) -> LowCutState? {
        EQReading.lowCut(strip) { cell($0).argument }
    }

    /// Empty when the strip's EQ is off, so the graph draws flat.
    public func eqBands(_ strip: StripID) -> [EQBandState] {
        EQReading.bands(strip) { cell($0).argument }
    }

    /// Puts every band back to `Catalog.eqDefaults`; a no-op on strips without defaults.
    public func resetEQBands(_ strip: StripID) {
        for index in (Catalog.eqDefaults(strip) ?? []).indices { resetEQBand(strip, index + 1) }
    }

    public func resetEQBand(_ strip: StripID, _ band: Int) {
        guard let defaults = Catalog.eqDefaults(strip), defaults.indices.contains(band - 1) else { return }
        let target = defaults[band - 1]
        let specs = Catalog.eqBand(strip, band)
        let values = [
            (specs.type, Double(target.typeIndex)), (specs.frequency, target.frequency), (specs.gain, target.gain),
            (specs.q, target.q),
        ]
        for (spec, value) in values {
            set(spec.address, spec.scale.argument(fromNormalized: spec.scale.normalized(forValue: value)))
        }
    }
}

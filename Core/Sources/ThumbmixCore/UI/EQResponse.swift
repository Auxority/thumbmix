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

    /// `bands` in band order: on a main or matrix, band 1 and 6 can be crossovers (`Crossover`).
    public static func decibels(at frequency: Double, bands: [EQBandState]) -> Double {
        bands.indices.reduce(0) { $0 + decibels(ofBand: $1 + 1, in: bands, at: frequency) }
    }

    private static func decibels(ofBand number: Int, in bands: [EQBandState], at frequency: Double) -> Double {
        if let crossover = Crossover(bands[number - 1], band: number, of: bands.count) {
            return crossover.decibels(at: frequency)
        }
        return Crossover.silences(band: number, in: bands) ? 0 : decibels(of: bands[number - 1], at: frequency)
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
        default:  // A crossover type on a band that takes none (`Crossover`): drawn flat.
            return nil
        }
    }
}

/// A main or matrix EQ's LOW (1) or HIGH (6) band set to BU6…LR24: Butterworth, Bessel or Linkwitz-Riley at
/// 6-24 dB/oct, and the band next to it (LOW2, HIGH2) is off (X32 manual; Maillot p.33 lists only the names).
/// Assumed: LOW cuts lows and HIGH cuts highs, like LCut and HCut; Bessel is -3 dB at the cutoff (TODO: desk).
struct Crossover {
    let typeIndex: Int
    let frequency: Double
    let highPass: Bool

    init?(_ band: EQBandState, band number: Int, of count: Int) {
        guard Self.isCrossover(band.typeIndex), count == 6, number == 1 || number == 6 else { return nil }
        typeIndex = band.typeIndex
        frequency = band.frequency
        highPass = number == 1
    }

    static func silences(band number: Int, in bands: [EQBandState]) -> Bool {
        guard bands.count == 6 else { return false }
        return (number == 2 && isCrossover(bands[0].typeIndex)) || (number == 5 && isCrossover(bands[5].typeIndex))
    }

    private static func isCrossover(_ typeIndex: Int) -> Bool { (6...13).contains(typeIndex) }

    func decibels(at hertz: Double) -> Double {
        // A high-pass is the low-pass mirrored around the cutoff.
        let ratio = highPass ? frequency / hertz : hertz / frequency
        switch typeIndex {
        case 6: return Self.butterworth(order: 1, ratio)  // BU6
        case 7: return Self.butterworth(order: 2, ratio)  // BU12
        case 8: return Self.bessel2(ratio)  // BS12
        case 9: return 2 * Self.butterworth(order: 1, ratio)  // LR12: two BU6 in series, -6 dB at the cutoff
        case 10: return Self.butterworth(order: 3, ratio)  // BU18
        case 11: return Self.butterworth(order: 4, ratio)  // BU24
        case 12: return Self.bessel4(ratio)  // BS24
        default: return 2 * Self.butterworth(order: 2, ratio)  // LR24: two BU12 in series
        }
    }

    private static func butterworth(order: Double, _ ratio: Double) -> Double {
        -10 * log10(1 + pow(ratio, 2 * order))
    }

    /// 3 / (s² + 3s + 3), its frequency scaled so the cutoff is at -3 dB.
    private static func bessel2(_ ratio: Double) -> Double {
        let w = ratio * 1.36165
        let real = 3 - w * w
        let imaginary = 3 * w
        return -10 * log10((real * real + imaginary * imaginary) / 9)
    }

    /// 105 / (s⁴ + 10s³ + 45s² + 105s + 105), scaled like `bessel2`.
    private static func bessel4(_ ratio: Double) -> Double {
        let w = ratio * 2.11391
        let real = pow(w, 4) - 45 * w * w + 105
        let imaginary = 105 * w - 10 * pow(w, 3)
        return -10 * log10((real * real + imaginary * imaginary) / (105 * 105))
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

    /// What is heard: empty when the strip's EQ is off, so the curve is flat.
    public static func bands(_ strip: StripID, value: (String) -> OSCArgument?) -> [EQBandState] {
        value(Catalog.eqOn(strip).address) == .int(1) ? bandsAsSet(strip, value: value) : []
    }

    /// The bands as set, heard or not.
    public static func bandsAsSet(_ strip: StripID, value: (String) -> OSCArgument?) -> [EQBandState] {
        guard strip.eqBandCount > 0 else { return [] }
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

    /// What is heard: empty when the strip's EQ is off, as for an unlinked partner's faint curve.
    public func eqBands(_ strip: StripID) -> [EQBandState] {
        EQReading.bands(strip) { cell($0).argument }
    }

    /// The bands as set, heard or not: the graph draws them dashed while the EQ is off.
    public func eqBandsAsSet(_ strip: StripID) -> [EQBandState] {
        EQReading.bandsAsSet(strip) { cell($0).argument }
    }

    /// false while the EQ is off or not read yet.
    public func isEQOn(_ strip: StripID) -> Bool {
        cell(Catalog.eqOn(strip).address).argument == .int(1)
    }

    /// false on a cut filter, whose Gain and Q do nothing; nil until the desk sent the band's type.
    public func eqBandShapesLevel(_ strip: StripID, _ band: Int) -> Bool? {
        let type = Catalog.eqBand(strip, band).type
        guard let position = normalized(type), case .choice(let names) = type.scale else { return nil }
        return Catalog.eqTypeShapesLevel(names[Int(type.scale.value(fromNormalized: position))])
    }

    /// Puts every band back to `Catalog.eqDefaults`; a no-op on strips without defaults.
    public func resetEQBands(_ strip: StripID) {
        for index in (Catalog.eqDefaults(strip) ?? []).indices { resetEQBand(strip, index + 1) }
    }

    public func resetEQBand(_ strip: StripID, _ band: Int) {
        for (address, argument) in Catalog.eqDefaultArguments(strip, band) { set(address, argument) }
    }
}

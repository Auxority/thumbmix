import Foundation

/// Values as the engineer reads them, in the phone's locale (decimal comma on a Dutch phone).
public enum ValueText {
    public static func format(_ normalized: Float?, _ spec: ParamSpec, locale: Locale = .current)
        -> String
    {
        guard let normalized else { return "—" }
        let value = spec.scale.value(fromNormalized: normalized)
        switch spec.scale {
        case .fader: return decibels(FaderLaw.shownDecibels(fromWire: Double(normalized)), locale: locale)
        case .choice(let options): return choice(options, index: value, unit: spec.unit)
        case .toggle: return value >= 1 ? CoreStrings.text("On") : CoreStrings.text("Off")
        default: return measurement(value, unit: spec.unit, locale: locale)
        }
    }

    private static func choice(_ options: [String], index: Double, unit: ParamUnit) -> String {
        let option = options[Swift.min(Swift.max(Int(index), 0), options.count - 1)]
        return unit == .ratio ? option + ":1" : option
    }

    private static func measurement(_ value: Double, unit: ParamUnit, locale: Locale) -> String {
        switch unit {
        case .decibels: return decibels(value, locale: locale)
        case .decibelAmount: return number(value, digits: 1, locale) + " dB"
        case .hertz: return hertz(value, locale)
        case .milliseconds: return milliseconds(value, locale)
        case .delayTime: return milliseconds(value, locale) + " · " + distance(milliseconds: value, locale)
        case .pan: return pan(value)
        case .percent: return (value / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
        case .ratio, .plain: return number(value, digits: 1, locale)
        }
    }

    /// Rounds before choosing the sign so the console's 0 dB (stored as -0.0098) never reads "−0.0".
    public static func decibels(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite else { return "−∞ dB" }
        let rounded = (value * 10).rounded() / 10
        guard rounded != 0 else { return number(0, digits: 1, locale) + " dB" }
        return (rounded > 0 ? "+" : "−") + number(abs(rounded), digits: 1, locale) + " dB"
    }

    /// No thousands separator: "4000 ms" reads better on a fader than "4,000 ms" or "4.000 ms".
    public static func number(_ value: Double, digits: Int, _ locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).grouping(.never).locale(locale))
    }

    private static func hertz(_ value: Double, _ locale: Locale) -> String {
        // The desk's own text (doc p.150 table): 124.7 Hz, and kHz cut to two decimals, "1k02" for 1025.7 Hz. The
        // 0.02 Hz lets 1909.985 Hz read "1k91" as the table does; with it, all 201 steps match.
        if value < 1000 { return number(value, digits: 1, locale) + " Hz" }
        let kilohertz = ((value + 0.02) / 10).rounded(.down) / 100
        return number(kilohertz, digits: 2, locale) + " kHz"
    }

    private static func milliseconds(_ value: Double, _ locale: Locale) -> String {
        let digits =
            switch value {
            case ..<10: 2
            case ..<100: 1
            default: 0
            }
        return number(value, digits: digits, locale) + " ms"
    }

    /// How far sound travels in that time (343 m/s, at 20 °C), for lining up a fill by its distance.
    /// Feet on a phone set to US units.
    private static func distance(milliseconds: Double, _ locale: Locale) -> String {
        let metres = milliseconds * 0.343
        guard locale.measurementSystem == .us else { return number(metres, digits: 1, locale) + " m" }
        return number(metres * 3.28084, digits: 1, locale) + " ft"
    }

    private static func pan(_ value: Double) -> String {
        let position = Int(value.rounded())
        return position == 0 ? "C" : position < 0 ? "L\(-position)" : "R\(position)"
    }
}

/// A value as the preset page shows it: the number, and its unit apart so the page can set it small and grey.
public struct ValueParts: Equatable, Sendable {
    public let number: String
    public let unit: String

    public init(number: String, unit: String = "") {
        self.number = number
        self.unit = unit
    }

    public var text: String { unit.isEmpty ? number : number + " " + unit }
}

/// The preset page's compact text (2026-10-28): "−18 dB", "4:1", "3 kHz", with no trailing zeros, so a page of values
/// reads at a glance. A control's own row keeps `format`, whose fixed decimals don't jump while a finger drags.
extension ValueText {
    public static func parts(_ normalized: Float?, _ spec: ParamSpec, locale: Locale = .current) -> ValueParts {
        guard let normalized else { return ValueParts(number: "—") }
        let value = spec.scale.value(fromNormalized: normalized)
        switch spec.scale {
        case .fader: return signed(FaderLaw.shownDecibels(fromWire: Double(normalized)), locale)
        case .choice(let options): return ValueParts(number: option(options, spec, index: value, locale))
        case .toggle: return ValueParts(number: value >= 1 ? CoreStrings.text("On") : CoreStrings.text("Off"))
        default: return compactMeasurement(value, unit: spec.unit, locale: locale)
        }
    }

    /// A ratio's option ("4.0") as a number of the phone's locale: "4:1", "1,1:1" on a Dutch phone.
    private static func option(_ options: [String], _ spec: ParamSpec, index: Double, _ locale: Locale) -> String {
        let position = Swift.min(Swift.max(Int(index), 0), options.count - 1)
        guard spec.unit == .ratio else { return spec.optionNames?[position] ?? options[position] }
        let ratio = Double(options[position]).map { compact($0, digits: 1, locale) } ?? options[position]
        return ratio + ":1"
    }

    private static func compactMeasurement(_ value: Double, unit: ParamUnit, locale: Locale) -> ValueParts {
        switch unit {
        case .decibels: return signed(value, locale)
        case .decibelAmount: return ValueParts(number: compact(value, digits: 1, locale), unit: "dB")
        case .hertz: return compactHertz(value, locale)
        case .milliseconds, .delayTime:
            let digits = value < 10 ? 2 : value < 100 ? 1 : 0
            return ValueParts(number: compact(value, digits: digits, locale), unit: "ms")
        case .pan: return ValueParts(number: pan(value))
        case .percent: return ValueParts(number: compact(value, digits: 0, locale), unit: "%")
        case .ratio, .plain: return ValueParts(number: compact(value, digits: 1, locale))
        }
    }

    /// As `decibels`: rounded before the sign is chosen, so the desk's 0 dB never reads "−0".
    private static func signed(_ value: Double, _ locale: Locale) -> ValueParts {
        guard value.isFinite else { return ValueParts(number: "−∞", unit: "dB") }
        let rounded = (value * 10).rounded() / 10
        let sign = rounded > 0 ? "+" : rounded < 0 ? "−" : ""
        return ValueParts(number: sign + compact(abs(rounded), digits: 1, locale), unit: "dB")
    }

    /// The desk's kHz text cut to two decimals as `hertz` does, then its trailing zeros dropped: "10.02 kHz", "3 kHz".
    private static func compactHertz(_ value: Double, _ locale: Locale) -> ValueParts {
        if value < 1000 { return ValueParts(number: compact(value, digits: 1, locale), unit: "Hz") }
        let kilohertz = ((value + 0.02) / 10).rounded(.down) / 100
        return ValueParts(number: compact(kilohertz, digits: 2, locale), unit: "kHz")
    }

    private static func compact(_ value: Double, digits: Int, _ locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)).grouping(.never).locale(locale))
    }
}

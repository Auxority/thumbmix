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
        // Three significant digits, like the desk: 91.4 Hz, 418 Hz, 1.91 kHz.
        if value < 100 { return number(value, digits: 1, locale) + " Hz" }
        return value < 1000 ? number(value, digits: 0, locale) + " Hz" : number(value / 1000, digits: 2, locale) + " kHz"
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

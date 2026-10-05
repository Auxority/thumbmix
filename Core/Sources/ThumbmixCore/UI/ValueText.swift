import Foundation

/// Values as the engineer reads them, in the phone's locale (decimal comma on a Dutch phone).
public enum ValueText {
    public static func format(_ normalized: Float?, _ spec: ParamSpec, locale: Locale = .current)
        -> String
    {
        guard let normalized else { return "—" }
        let value = spec.scale.value(fromNormalized: normalized)
        switch spec.scale {
        case .choice(let options):
            let option = options[Swift.min(Swift.max(Int(value), 0), options.count - 1)]
            return spec.unit == .ratio ? option + ":1" : option
        case .toggle:
            return value >= 1 ? CoreStrings.text("On") : CoreStrings.text("Off")
        default:
            break
        }
        switch spec.unit {
        case .decibels: return decibels(value, locale: locale)
        case .decibelAmount: return number(value, digits: 1, locale) + " dB"
        case .hertz:
            return value < 1000
                ? number(value, digits: 0, locale) + " Hz"
                : number(value / 1000, digits: 2, locale) + " kHz"
        case .milliseconds: return milliseconds(value, locale)
        case .percent: return number(value, digits: 0, locale) + "%"
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

    private static func milliseconds(_ value: Double, _ locale: Locale) -> String {
        let digits =
            switch value {
            case ..<10: 2
            case ..<100: 1
            default: 0
            }
        return number(value, digits: digits, locale) + " ms"
    }

    private static func pan(_ value: Double) -> String {
        let position = Int(value.rounded())
        return position == 0 ? "C" : position < 0 ? "L\(-position)" : "R\(position)"
    }
}

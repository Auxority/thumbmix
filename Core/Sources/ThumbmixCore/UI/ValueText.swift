import Foundation

public enum ValueText {
    public static func format(_ normalized: Float?, _ spec: ParamSpec) -> String {
        guard let normalized else { return "—" }
        let value = spec.scale.value(fromNormalized: normalized)
        switch spec.scale {
        case let .choice(options):
            let option = options[Swift.min(Swift.max(Int(value), 0), options.count - 1)]
            return spec.unit == .ratio ? option + ":1" : option
        case .toggle:
            return value >= 1 ? "On" : "Off"
        default:
            break
        }
        switch spec.unit {
        case .decibels: return decibels(value)
        case .decibelAmount: return String(format: "%.1f dB", value)
        case .hertz: return value < 1000 ? String(format: "%.0f Hz", value) : String(format: "%.2f kHz", value / 1000)
        case .milliseconds: return milliseconds(value)
        case .percent: return String(format: "%.0f%%", value)
        case .pan: return pan(value)
        case .ratio, .plain: return String(format: "%.1f", value)
        }
    }

    /// Rounds before choosing the sign so the console's 0 dB (stored as -0.0098) never reads "−0.0".
    public static func decibels(_ value: Double) -> String {
        guard value.isFinite else { return "−∞ dB" }
        let rounded = (value * 10).rounded() / 10
        guard rounded != 0 else { return "0.0 dB" }
        return (rounded > 0 ? "+" : "−") + String(format: "%.1f dB", abs(rounded))
    }

    private static func milliseconds(_ value: Double) -> String {
        switch value {
        case ..<10: String(format: "%.2f ms", value)
        case ..<100: String(format: "%.1f ms", value)
        default: String(format: "%.0f ms", value)
        }
    }

    private static func pan(_ value: Double) -> String {
        let position = Int(value.rounded())
        return position == 0 ? "C" : position < 0 ? "L\(-position)" : "R\(position)"
    }
}

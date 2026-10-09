import Foundation

/// A value typed into a row's alert. A number outside the range lands on its nearest end ("100" on a fader is
/// +10 dB): the alert's Set is the confirmation. The desk snaps to its own grid, so the result is snapped too.
public enum ValueInput {
    /// The 0...1 position for `text`, or nil when it isn't a value of this parameter.
    public static func normalized(from text: String, for spec: ParamSpec) -> Float? {
        let typed = text.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: ",", with: ".")
        switch spec.scale {
        case .toggle: return nil
        case .fader, .sendLevel: return level(typed, spec.scale)
        case .choice(let options): return choice(typed, options: options, scale: spec.scale)
        case .linear, .log:
            let value = spec.unit == .pan ? pan(typed) : number(typed)
            return value.map(spec.scale.normalized(forValue:))
        }
    }

    /// The range as the row shows its values, low to high: "−∞ dB to +10.0 dB", "0.3 to 10.0" for Q.
    public static func rangeText(_ spec: ParamSpec, locale: Locale = .current) -> String {
        let ends: [Float] = spec.scale.value(fromNormalized: 0) <= spec.scale.value(fromNormalized: 1) ? [0, 1] : [1, 0]
        let low = ValueText.format(ends[0], spec, locale: locale)
        let high = ValueText.format(ends[1], spec, locale: locale)
        return CoreStrings.text("\(low) to \(high)")
    }

    /// Unit suffixes an engineer may add, with what they multiply by; "k" is kilohertz.
    private static let suffixes: [(String, Double)] = [
        ("khz", 1000), ("hz", 1), ("k", 1000), ("db", 1), ("ms", 1), (":1", 1),
    ]

    private static func number(_ typed: String) -> Double? {
        guard let (suffix, factor) = suffixes.first(where: { typed.hasSuffix($0.0) }) else { return finite(typed) }
        return finite(typed.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)).map { $0 * factor }
    }

    /// Swift also reads "nan" and "inf" as numbers; a NaN must never reach the desk.
    private static func finite<Text: StringProtocol>(_ text: Text) -> Double? {
        Double(text).flatMap { $0.isFinite ? $0 : nil }
    }

    /// Faders and sends: dB, or −∞ by name.
    private static func level(_ typed: String, _ scale: ParamScale) -> Float? {
        let bare = typed.hasSuffix("db") ? typed.dropLast(2).trimmingCharacters(in: .whitespaces) : typed
        if ["-inf", "-∞", "off"].contains(bare) { return 0 }
        return number(typed).map(scale.normalized(forValue:))
    }

    /// Pan as the row shows it: "L20", "R30", "C", or a plain number from −100 (left) to 100.
    private static func pan(_ typed: String) -> Double? {
        if typed == "c" { return 0 }
        if typed.hasPrefix("l") { return finite(typed.dropFirst()).map { -$0 } }
        if typed.hasPrefix("r") { return finite(typed.dropFirst()) }
        return finite(typed)
    }

    /// A list of the desk's numbers (the ratio) takes the nearest one; a list of names takes a name.
    private static func choice(_ typed: String, options: [String], scale: ParamScale) -> Float? {
        let values = options.compactMap(finite)
        let index: Int?
        if values.count == options.count, let typedValue = number(typed) {
            index = values.indices.min { abs(values[$0] - typedValue) < abs(values[$1] - typedValue) }
        } else {
            index = options.firstIndex { $0.lowercased() == typed }
        }
        return index.map { scale.normalized(forValue: Double($0)) }
    }
}

import Foundation

/// A value typed into a row's alert. A number past either end is refused, never moved onto that end: a slip such as
/// "100" on a fader must not set +10 dB. The desk snaps to its own grid, so an accepted value is snapped too.
public enum ValueInput {
    public enum Reading: Equatable, Sendable {
        /// The snapped 0...1 position.
        case value(Float)
        case notAValue
        case outOfRange
    }

    public static func read(_ text: String, for spec: ParamSpec) -> Reading {
        let typed = text.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: ",", with: ".")
        switch spec.scale {
        case .toggle: return .notAValue
        case .choice(let options): return choice(typed, options: options, scale: spec.scale)
        case .fader, .sendLevel: return checked(level(typed), spec.scale)
        case .linear, .log: return checked(spec.unit == .pan ? pan(typed) : number(typed), spec.scale)
        }
    }

    /// The range as the row shows its values, low to high: "−∞ dB to +10.0 dB", "0.3 to 10.0" for Q.
    public static func rangeText(_ spec: ParamSpec, locale: Locale = .current) -> String {
        let ends: [Float] = spec.scale.value(fromNormalized: 0) <= spec.scale.value(fromNormalized: 1) ? [0, 1] : [1, 0]
        let low = ValueText.format(ends[0], spec, locale: locale)
        let high = ValueText.format(ends[1], spec, locale: locale)
        return CoreStrings.text("\(low) to \(high)")
    }

    private static func checked(_ value: Double?, _ scale: ParamScale) -> Reading {
        guard let value else { return .notAValue }
        let ends = [scale.value(fromNormalized: 0), scale.value(fromNormalized: 1)]
        guard within(value, ends.min()!...ends.max()!) else { return .outOfRange }
        return .value(scale.normalized(forValue: value))
    }

    /// The scale's maths can put an end a hair off its round number (20 kHz as 19999.999…), so typing the end as the
    /// row shows it gets a tiny slack. An infinite end (the fader's −∞) needs none.
    private static func within(_ value: Double, _ ends: ClosedRange<Double>) -> Bool {
        func slack(_ end: Double) -> Double { end.isFinite ? 1e-9 * Swift.max(1, abs(end)) : 0 }
        return value >= ends.lowerBound - slack(ends.lowerBound) && value <= ends.upperBound + slack(ends.upperBound)
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
    private static func level(_ typed: String) -> Double? {
        let bare = typed.hasSuffix("db") ? typed.dropLast(2).trimmingCharacters(in: .whitespaces) : typed
        if ["-inf", "-∞", "off"].contains(bare) { return -.infinity }
        return number(typed)
    }

    /// Pan as the row shows it: "L20", "R30", "C", or a plain number from −100 (left) to 100.
    private static func pan(_ typed: String) -> Double? {
        if typed == "c" { return 0 }
        if typed.hasPrefix("l") { return finite(typed.dropFirst()).map { -$0 } }
        if typed.hasPrefix("r") { return finite(typed.dropFirst()) }
        return finite(typed)
    }

    /// A list of the desk's numbers (the ratio) takes the nearest one within its first and last; a list of names
    /// takes a name.
    private static func choice(_ typed: String, options: [String], scale: ParamScale) -> Reading {
        let values = options.compactMap(finite)
        guard values.count == options.count else {
            let index = options.firstIndex { $0.lowercased() == typed }
            return index.map { .value(scale.normalized(forValue: Double($0))) } ?? .notAValue
        }
        guard let typedValue = number(typed) else { return .notAValue }
        guard within(typedValue, values.min()!...values.max()!) else { return .outOfRange }
        let index = values.indices.min { abs(values[$0] - typedValue) < abs(values[$1] - typedValue) }!
        return .value(scale.normalized(forValue: Double(index)))
    }
}

import Foundation

/// One question a load asks before it writes: the alert's words and what it holds back. Answering "keep" drops only
/// `writes`; the rest of the preset still loads (the user, 2026-10-27).
public struct PresetQuestion: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case gain, trim
        case phantom(on: Bool)
        case polarity, compMove
    }

    public let id: Int
    public let kind: Kind
    public let title: String
    public let message: String?
    /// The button that lets the write through.
    public let confirm: String
    /// The cancel button, which names what stays.
    public let keep: String
    let writes: [PresetWrite]

    static func raise(id: Int, isGain: Bool, who: PresetWho, from: Double, to: Double, writes: [PresetWrite]) -> Self {
        let (low, high) = (decibels(from, who.locale), decibels(to, who.locale))
        let name = who.name
        return PresetQuestion(
            id: id, kind: isGain ? .gain : .trim,
            title: isGain
                ? CoreStrings.text("Raise the gain of \(name) from \(low) to \(high)?")
                : CoreStrings.text("Raise the trim of \(name) from \(low) to \(high)?"),
            message: isGain ? who.sameInput.map { CoreStrings.text("Also changes the gain of \($0) (same input).") } : nil,
            confirm: CoreStrings.text("Raise"), keep: CoreStrings.text("Keep \(low)"), writes: writes)
    }

    static func phantom(id: Int, on: Bool, who: PresetWho, writes: [PresetWrite]) -> Self {
        let name = who.name
        return PresetQuestion(
            id: id, kind: .phantom(on: on),
            title: on ? CoreStrings.text("Turn on 48V for \(name)?") : CoreStrings.text("Turn off 48V for \(name)?"),
            message: who.sameInput.map { CoreStrings.text("Also powers \($0) (same input).") },
            confirm: on ? CoreStrings.text("Turn On") : CoreStrings.text("Turn Off"),
            keep: on ? CoreStrings.text("Keep 48V off") : CoreStrings.text("Keep 48V on"), writes: writes)
    }

    static func polarity(id: Int, isFlipped: Bool, who: PresetWho, writes: [PresetWrite]) -> Self {
        let prompt = PolarityPrompt(name: who.name, isFlipped: isFlipped, partner: nil)
        return PresetQuestion(
            id: id, kind: .polarity, title: prompt.title, message: prompt.message, confirm: prompt.confirm,
            keep: CoreStrings.text("Keep"), writes: writes)
    }

    static func compMove(id: Int, movesBeforeEQ: Bool, mixes: [String], writes: [PresetWrite]) -> Self {
        let prompt = CompMovePrompt(movesBeforeEQ: movesBeforeEQ, mixes: mixes)
        return PresetQuestion(
            id: id, kind: .compMove, title: prompt.title, message: prompt.message, confirm: CoreStrings.text("Move"),
            keep: CoreStrings.text("Keep"), writes: writes)
    }

    private static func decibels(_ value: Double, _ locale: Locale) -> String {
        CoreStrings.text("\(value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))) dB")
    }
}

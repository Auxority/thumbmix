/// What the Ø button's alert says (mock A, 2026-10-12). Polarity is hard to grasp, so flipping it explains when it
/// helps; flipping back only asks. A partner the desk's Gain/Delay link reaches is named, like in the 48V alert.
public struct PolarityPrompt: Equatable, Sendable {
    public let title: String
    public let message: String?
    public let confirm: String

    public init(name: String, isFlipped: Bool, partner: String?) {
        if isFlipped {
            title = CoreStrings.text("Set \(name)'s polarity back to normal?")
            message = partner.map { CoreStrings.text("Also sets \($0) back (linked).") }
            confirm = CoreStrings.text("Normal")
        } else {
            title = CoreStrings.text("Flip the polarity of \(name)?")
            let explanation = CoreStrings.text(
                "Turns the signal upside down. Try it when two mics on one source sound thin together.")
            message = ([explanation] + [partner.map { CoreStrings.text("Also flips \($0) (linked).") }].compactMap { $0 })
                .joined(separator: "\n")
            confirm = CoreStrings.text("Flip")
        }
    }
}

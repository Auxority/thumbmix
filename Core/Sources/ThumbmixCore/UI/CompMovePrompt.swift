/// Moving the comp across the EQ changes what sends tapped around the EQ hear, so the alert names those mixes
/// (mock b1, 2026-10-14). Every mix named changes the same way: all start hearing the comp, or all stop.
public struct CompMovePrompt: Equatable, Sendable {
    public let title: String
    public let message: String

    /// PRE (0) puts the comp before the EQ (doc p.25).
    public init(movesBeforeEQ: Bool, mixes: [String]) {
        let names = mixes.joined(separator: " · ")
        title =
            movesBeforeEQ
            ? CoreStrings.text("Move the comp before the EQ?") : CoreStrings.text("Move the comp after the EQ?")
        if mixes.count == 1 {
            message =
                movesBeforeEQ
                ? CoreStrings.text("\(names) will start hearing the compressor.")
                : CoreStrings.text("\(names) will stop hearing the compressor.")
        } else {
            message =
                movesBeforeEQ
                ? CoreStrings.text("These \(mixes.count) mixes will start hearing the compressor:\n\n\(names)")
                : CoreStrings.text("These \(mixes.count) mixes will stop hearing the compressor:\n\n\(names)")
        }
    }
}

/// Scribble-strip colour: 0-7 = OFF, RD, GN, YE, BL, MG, CY, WH; 8-15 = the same, inverted (doc p.25).
public struct ConsoleColor: Equatable, Sendable {
    public enum Base: Int, CaseIterable, Sendable { case off, red, green, yellow, blue, magenta, cyan, white }

    public let base: Base
    public let inverted: Bool

    public init(base: Base, inverted: Bool) {
        self.base = base
        self.inverted = inverted
    }

    public init(index: Int) {
        let valid = (0...15).contains(index) ? index : 0
        self.init(base: Base(rawValue: valid % 8) ?? .off, inverted: valid >= 8)
    }

    /// The `config/color` value the desk expects.
    public var index: Int { base.rawValue + (inverted ? 8 : 0) }
}

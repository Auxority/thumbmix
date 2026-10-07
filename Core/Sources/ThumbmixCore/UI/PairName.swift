import Foundation

/// The one name a linked pair shows: what both desk names start with, so neither side looks more important.
public enum PairName {
    public static func make(odd: String, even: String, fallback: String) -> String {
        switch (odd.isEmpty, even.isEmpty) {
        case (true, true): fallback
        case (false, true): odd
        case (true, false): even
        case (false, false): sharedStart(odd, even) ?? odd
        }
    }

    /// Cut only at a word boundary: "Guitar"/"Guiro" share "Gui", which names neither.
    private static func sharedStart(_ odd: String, _ even: String) -> String? {
        let common = String(zip(odd, even).prefix { $0 == $1 }.map(\.0))
        guard !common.isEmpty, endsAtBoundary(common, odd, even) else { return nil }
        let trimmed = String(common.reversed().drop(while: isSeparator).reversed())
        return trimmed.isEmpty ? nil : trimmed
    }

    /// A boundary is a separator, a digit or a name's end after the shared part, or a lone L/R that differs ("OHL"/"OHR").
    private static func endsAtBoundary(_ common: String, _ odd: String, _ even: String) -> Bool {
        if common.last.map(isSeparator) == true { return true }
        let rests = [odd, even].map { $0.dropFirst(common.count) }
        if rests.allSatisfy({ ["L", "R"].contains($0.uppercased()) }) { return true }
        return rests.allSatisfy { rest in rest.first.map { isSeparator($0) || $0.isNumber } ?? true }
    }

    private static func isSeparator(_ character: Character) -> Bool {
        " -_./".contains(character)
    }
}

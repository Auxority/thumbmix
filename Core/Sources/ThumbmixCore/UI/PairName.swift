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

    /// Cut only at a word boundary: "Guitar"/"Guiro" share "Gui", which names neither. A cut inside a word or number
    /// backs off to the last separator: "Ch 1"/"Ch 12" → "Ch".
    private static func sharedStart(_ odd: String, _ even: String) -> String? {
        var common = String(zip(odd, even).prefix { $0 == $1 }.map(\.0))
        if !endsAtBoundary(common, odd, even) {
            guard let cut = common.lastIndex(where: isSeparator) else { return nil }
            common = String(common[...cut])
        }
        let trimmed = String(common.reversed().drop(while: isSeparator).reversed())
        return trimmed.isEmpty ? nil : trimmed
    }

    /// A boundary is a separator or a name's end after the shared part, a digit after letters ("Synth1"/"Synth2"),
    /// or a capital L and R that differ ("OHL"/"OHR"; "Pal"/"Par" is one word).
    private static func endsAtBoundary(_ common: String, _ odd: String, _ even: String) -> Bool {
        if common.last.map(isSeparator) == true { return true }
        let rests = [odd, even].map { String($0.dropFirst(common.count)) }
        if Set(rests) == ["L", "R"] { return true }
        let insideNumber = common.last?.isNumber == true
        return rests.allSatisfy { rest in rest.first.map { isSeparator($0) || ($0.isNumber && !insideNumber) } ?? true }
    }

    private static func isSeparator(_ character: Character) -> Bool {
        " -_./".contains(character)
    }
}

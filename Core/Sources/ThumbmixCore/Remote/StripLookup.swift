import Foundation

/// How a client points at a strip: the id the API prints ("ch/01") or the name the desk shows.
struct StripLookup {
    enum Match: Equatable {
        case found(StripID)
        case ambiguous([StripID])
        case unknown
    }

    struct Entry {
        let strip: StripID
        /// What the desk calls it, and the default name an unnamed strip shows.
        let names: [String]
    }

    let entries: [Entry]

    /// An id first. Then a name, ignoring case and diacritics as presets do (`PresetMatching`): one that equals a name
    /// wins over longer names that merely contain it ("Bass" over "Bass Guitar"); otherwise a part of a name will do,
    /// but only when a single strip fits.
    func match(_ query: String) -> Match {
        if let strip = Self.strip(withID: query) { return .found(strip) }
        let wanted = Self.fold(query)
        guard !wanted.isEmpty else { return .unknown }
        let exact = strips(whereAName: { $0 == wanted })
        return verdict(exact.isEmpty ? strips(whereAName: { $0.contains(wanted) }) : exact)
    }

    private func strips(whereAName fits: (String) -> Bool) -> [StripID] {
        entries.filter { $0.names.contains { fits(Self.fold($0)) } }.map(\.strip)
    }

    private func verdict(_ candidates: [StripID]) -> Match {
        switch candidates.count {
        case 0: .unknown
        case 1: .found(candidates[0])
        default: .ambiguous(candidates)
        }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    // MARK: Ids

    private static let paths: [(path: String, kind: StripKind)] = [
        ("ch", .input), ("auxin", .auxIn), ("fxrtn", .fxReturn), ("bus", .bus), ("mtx", .matrix), ("dca", .dca),
    ]

    /// The OSC prefix without its leading slash, as the desk's addresses spell it: "ch/01", "main/st", "dca/2".
    static func id(of strip: StripID) -> String {
        String(strip.prefix.dropFirst())
    }

    static func strip(withID id: String) -> StripID? {
        let parts = id.trimmingCharacters(in: .whitespaces).lowercased().split(separator: "/", omittingEmptySubsequences: false)
        let words = parts.first == "" ? Array(parts.dropFirst()) : parts
        guard words.count == 2 else { return nil }
        if words[0] == "main" { return mains[String(words[1])] }
        guard let kind = paths.first(where: { $0.path == words[0] })?.kind, words[1].allSatisfy({ $0.isASCII && $0.isNumber }),
            let number = Int(words[1]), (1...kind.count).contains(number)
        else { return nil }
        return StripID(kind, number)
    }

    private static let mains = ["st": StripID(.mainStereo), "m": StripID(.mainMono)]
}

import Foundation

/// Which strips a preset's match words point at (the preset list puts those first).
public enum PresetMatching {
    /// A word fits when the strip's name contains it, ignoring case and diacritics ("kick" fits "Kick In"). No words
    /// fit nothing, and neither does an empty word or an unnamed strip.
    public static func fits(_ preset: Preset, name: String) -> Bool {
        let folded = fold(name)
        guard !folded.isEmpty else { return false }
        return preset.matchWords.map(fold).contains { !$0.isEmpty && folded.contains($0) }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }
}

extension ConsoleMirror {
    /// The strips named as the preset's words say, in desk order. The desk's own name is matched, not the "Ch 1"
    /// fallback an unnamed strip shows; DCAs have no parts to load.
    public func fittingStrips(_ preset: Preset) -> [StripID] {
        StripKind.allCases.filter { $0 != .dca }.flatMap(StripID.all).filter {
            PresetMatching.fits(preset, name: rawName($0))
        }
    }
}

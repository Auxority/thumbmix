import Foundation

/// The link alert's optional line: what the desk's Link Preferences keep separate when a pair is linked.
public enum LinkPrompt {
    public static func separateLine(_ separate: Set<LinkSection>, locale: Locale = .current) -> String? {
        let parts = LinkSection.allCases.filter(separate.contains)
        guard !parts.isEmpty else { return nil }
        let list = parts.map(\.partName).formatted(.list(type: .and).locale(locale))
        let sentence = list.prefix(1).uppercased() + list.dropFirst()
        // "EQ" is the one part named as a single thing.
        return parts == [.eq]
            ? CoreStrings.text("\(sentence) stays separate.") : CoreStrings.text("\(sentence) stay separate.")
    }
}

extension LinkSection {
    /// Lower case for the middle of a sentence, like the desk's Link Preferences page.
    var partName: String {
        switch self {
        case .gainDelay: CoreStrings.text("gain and delay")
        case .eq: CoreStrings.text("EQ")
        case .dynamics: CoreStrings.text("dynamics")
        case .faderMute: CoreStrings.text("fader and mute")
        }
    }
}

extension ConsoleMirror {
    public var separateSections: Set<LinkSection> {
        Set(LinkSection.allCases.filter { !isShared($0) })
    }
}

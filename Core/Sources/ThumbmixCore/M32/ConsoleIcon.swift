import Foundation

/// The desk's 74 scribble-strip icons (`config/icon`, 1-74), named as in the doc's appendix (p.138).
/// The desk's artwork can't be reused, so each gets an emoji: built into iOS, nothing to bundle.
/// Several icons share one emoji; the name under it tells them apart.
public struct ConsoleIcon: Identifiable, Equatable, Sendable {
    public let number: Int
    public let name: String
    public let emoji: String

    public var id: Int { number }

    public struct Group: Identifiable, Sendable {
        public let title: String
        public let icons: [ConsoleIcon]
        public var id: String { title }

        public init(title: String, icons: [ConsoleIcon]) {
            self.title = title
            self.icons = icons
        }
    }

    /// Unknown numbers fall back to "None" (1), like an unset icon on the desk.
    public static func icon(_ number: Int) -> ConsoleIcon {
        all.indices.contains(number - 1) ? all[number - 1] : all[0]
    }

    public static let groups: [Group] = [
        Group(title: CoreStrings.text("Drums & percussion"), icons: Array(all[1...15])),
        Group(title: CoreStrings.text("Bass & guitar"), icons: Array(all[16...25])),
        Group(title: CoreStrings.text("Keys"), icons: Array(all[26...33])),
        Group(title: CoreStrings.text("Brass, wind & strings"), icons: Array(all[34...39])),
        Group(title: CoreStrings.text("Vocals & mics"), icons: Array(all[40...52])),
        Group(title: CoreStrings.text("Cables & playback"), icons: Array(all[53...61])),
        Group(title: CoreStrings.text("Speakers & routing"), icons: Array(all[62...72])),
        Group(title: CoreStrings.text("Other"), icons: [all[0], all[73]]),
    ]

    public static let all: [ConsoleIcon] = [
        ("None", "⬜"), ("Kick Back", "🥁"), ("Kick Front", "🥁"), ("Snare Top", "🥁"), ("Snare Bottom", "🥁"),
        ("High Tom", "🥁"), ("Mid Tom", "🥁"), ("Floor Tom", "🥁"), ("Hi-Hat", "🔔"), ("Ride", "🔔"),
        ("Drum Kit", "🥁"), ("Cowbell", "🔔"), ("Bongos", "🪘"), ("Congas", "🪘"), ("Tambourine", "🪇"),
        ("Vibraphone", "🎶"), ("Electric Bass", "🎸"), ("Acoustic Bass", "🎸"), ("Contrabass", "🎻"),
        ("Les Paul Guitar", "🎸"), ("Ibanez Guitar", "🎸"), ("Washburn Guitar", "🎸"), ("Acoustic Guitar", "🎸"),
        ("Bass Amp", "🔊"), ("Guitar Amp", "🔊"), ("Amp Cabinet", "🔈"), ("Piano", "🎹"), ("Organ", "🎹"),
        ("Harpsichord", "🎹"), ("Keyboard", "🎹"), ("Synthesizer 1", "🎛️"), ("Synthesizer 2", "🎛️"),
        ("Synthesizer 3", "🎛️"), ("Keytar", "🎹"), ("Trumpet", "🎺"), ("Trombone", "🎺"), ("Saxophone", "🎷"),
        ("Clarinet", "🪈"), ("Violin", "🎻"), ("Cello", "🎻"), ("Male Vocal", "🎤"), ("Female Vocal", "🎤"),
        ("Choir", "👥"), ("Hand Sign", "✋"), ("Talk A", "🗣️"), ("Talk B", "🗣️"), ("Large Diaphragm Mic", "🎙️"),
        ("Condenser Mic Left", "🎙️"), ("Condenser Mic Right", "🎙️"), ("Handheld Mic", "🎤"), ("Wireless Mic", "🎤"),
        ("Podium Mic", "🎙️"), ("Headset Mic", "🎧"), ("XLR Jack", "🔌"), ("TRS Plug", "🔌"), ("TRS Plug Left", "🔌"),
        ("TRS Plug Right", "🔌"), ("RCA Plug Left", "🔌"), ("RCA Plug Right", "🔌"), ("Reel to Reel", "📼"),
        ("FX", "✨"), ("Computer", "💻"), ("Monitor Wedge", "🔈"), ("Left Speaker", "🔊"), ("Right Speaker", "🔊"),
        ("Speaker Array", "📢"), ("Speaker on a Pole", "📢"), ("Amp Rack", "🗄️"), ("Controls", "🎛️"),
        ("Faders", "🎚️"), ("MixBus", "🎚️"), ("Matrix", "🔀"), ("Routing", "🔀"), ("Smiley", "🙂"),
    ].enumerated().map { ConsoleIcon(number: $0.offset + 1, name: $0.element.0, emoji: $0.element.1) }
}

/// What the desk stores as a strip name: at most 12 characters (doc p.25) of plain printable ASCII,
/// so a name typed on the phone reads the same on the scribble strip.
public enum StripName {
    public static let maxLength = 12

    /// For the text field while typing: accents become plain letters, everything else non-ASCII goes.
    public static func typed(_ text: String) -> String {
        let plain = text.applyingTransform(.stripDiacritics, reverse: false) ?? text
        let printable = plain.unicodeScalars.filter { (0x20...0x7E).contains($0.value) }
        return String(String(String.UnicodeScalarView(printable)).prefix(maxLength))
    }

    /// For sending: as typed, without surrounding spaces.
    public static func sanitized(_ text: String) -> String {
        typed(text.trimmingCharacters(in: .whitespacesAndNewlines)).trimmingCharacters(in: .whitespaces)
    }
}

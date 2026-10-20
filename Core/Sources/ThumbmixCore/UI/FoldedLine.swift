import Foundation

/// The one line a set-once block folds into (mocks 2026-10-20-fewer-options): what's inside, over its values.
/// A tap opens the block in a sheet, so the tab never changes length.
public struct FoldedLine: Equatable, Sendable {
    public let names: String
    public let values: String
    /// On or off after the values, one per side when a pair's sides differ (odd first): drawn as a green "On" or a
    /// grey "Off" (B, 2026-10-20), in words too so it reads without colour.
    public let states: [Bool]

    public init(names: String, values: String, states: [Bool] = []) {
        self.names = names
        self.values = values
        self.states = states
    }

    public static func word(_ isOn: Bool) -> String { isOn ? CoreStrings.text("On") : CoreStrings.text("Off") }

    /// The whole line as one text, for VoiceOver.
    public var text: String {
        states.isEmpty ? values : values + " · " + states.map(Self.word).joined(separator: " / ")
    }
}

extension ConsoleMirror {
    /// Detector, Envelope, Comp position and the key: the comp settings nobody rides.
    public func compFold(_ strip: StripID, locale: Locale = .current) -> FoldedLine {
        let dynamics = Catalog.dynamics(strip)
        var parts = [
            (CoreStrings.text("Detector"), shown(dynamics.detector, locale)),
            (CoreStrings.text("Envelope"), shown(dynamics.envelope, locale)),
        ]
        if let position = Catalog.dynamicsPosition(strip) {
            parts.append((CoreStrings.text("Position"), named(position, locale)))
        }
        parts.append((CoreStrings.text("Key"), keyText(Catalog.dynamicsKey(strip), locale)))
        return FoldedLine(names: parts.map(\.0).joined(separator: " · "), values: parts.map(\.1).joined(separator: " · "))
    }

    public func gateKeyFold(_ strip: StripID, locale: Locale = .current) -> FoldedLine {
        FoldedLine(names: CoreStrings.text("Key"), values: keyText(Catalog.gateKey(strip), locale))
    }

    /// `blocks` as `insertBlocks(_:partner:)` gives them: one block, or one per side of a pair the desk doesn't link.
    public func insertFold(_ blocks: [[StripID]], locale: Locale = .current) -> FoldedLine {
        let sides = blocks.flatMap { $0 }
        // Unread counts as neither empty nor set, as in the block itself.
        guard !sides.isEmpty, isInsertRead(sides) else { return FoldedLine(names: CoreStrings.text("Insert"), values: "—") }
        var parts = [CoreStrings.text("Insert")]
        if blocks.count > 1 { parts.append(blocks.map { name($0[0]) }.joined(separator: " / ")) }
        parts.append(perBlock(blocks) { self.insertSpec($0).map { self.named($0.position, locale) } ?? "—" })
        let names = parts.joined(separator: " · ")
        if sides.compactMap(insertSlot).allSatisfy({ $0 == .none }) {
            return FoldedLine(names: names, values: CoreStrings.text("No slot picked on the desk"))
        }
        // One state when every block agrees, else each block's: never one side's alone.
        let states = blocks.map { cell(Catalog.insert($0[0])?.on.address ?? "").argument == .int(1) }
        return FoldedLine(
            names: names, values: insertLabel(sides) ?? "—", states: Set(states).count == 1 ? [states[0]] : states)
    }

    /// "Comp · Vox 1". A linked pair reads as one, unless the tab shows one side of a section the desk doesn't link.
    public func sheetTitle(_ section: String, strip: StripID, perSide: Bool) -> String {
        section + " · " + (perSide || !isLinked(strip) ? name(strip) : pairName(strip))
    }

    private func insertSpec(_ strip: StripID) -> InsertSpecs? { Catalog.insert(strip) }

    /// One text when every block agrees, else each block's in odd-even order ("On / Off"): never one side's alone.
    private func perBlock(_ blocks: [[StripID]], _ text: (StripID) -> String) -> String {
        let texts = blocks.map { text($0[0]) }
        return Set(texts).count == 1 ? texts[0] : texts.joined(separator: " / ")
    }

    /// The source, then the filter while it's on. Without a source (a matrix's or main's comp) an off filter says so.
    private func keyText(_ key: KeySpecs, _ locale: Locale) -> String {
        var parts: [String] = []
        if let source = key.sourceAddress { parts.append(shown(Catalog.keySource(source, rawName: rawName), locale)) }
        switch normalized(key.filterOn).map({ $0 >= 0.5 }) {
        case true?: parts.append(filterText(key, locale))
        case false? where parts.isEmpty: parts.append(CoreStrings.text("Filter off"))
        case false?: break
        case nil: parts.append("—")
        }
        return parts.joined(separator: " · ")
    }

    /// "LC12 150 Hz"; one "—" while either is unread, not "— —".
    private func filterText(_ key: KeySpecs, _ locale: Locale) -> String {
        guard normalized(key.filterType) != nil, normalized(key.filterFrequency) != nil else { return "—" }
        return shown(key.filterType, locale) + " " + shown(key.filterFrequency, locale)
    }

    /// As the closed control shows it; "—" until the desk sent it.
    private func shown(_ spec: ParamSpec, _ locale: Locale) -> String {
        ValueText.format(normalized(spec), spec, locale: locale)
    }

    /// A position's words ("After EQ"): its desk term (POST) doesn't say what it's after.
    private func named(_ spec: ParamSpec, _ locale: Locale) -> String {
        guard let value = normalized(spec), let names = spec.optionNames else { return shown(spec, locale) }
        let index = Int(spec.scale.value(fromNormalized: value))
        return names[min(max(index, 0), names.count - 1)]
    }
}

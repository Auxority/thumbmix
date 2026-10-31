import Foundation

/// The one line a set-once block folds into (mocks 2026-10-20-fewer-options): what's inside, over its values.
/// A tap opens the block in a sheet, so the tab never changes length.
public struct FoldedLine: Equatable, Sendable {
    public let names: String
    public let values: String
    /// On or off after the values, one per side when a pair's sides differ (odd first): drawn as a green "On" or a
    /// grey "Off" (B, 2026-10-20), in words too so it reads without colour.
    public let states: [Bool]
    public let subject: Subject

    /// What the state is about. A Key line's "On" would read as the key or the comp being on (Slim, 2026-10-31).
    public enum Subject: Equatable, Sendable {
        case block, keyFilter
    }

    public init(names: String, values: String, states: [Bool] = [], subject: Subject = .block) {
        self.names = names
        self.values = values
        self.states = states
        self.subject = subject
    }

    public static func word(_ isOn: Bool) -> String { isOn ? CoreStrings.text("On") : CoreStrings.text("Off") }

    /// "On", or "Filter on" on a Key line.
    public func word(_ isOn: Bool) -> String {
        switch subject {
        case .block: Self.word(isOn)
        case .keyFilter: isOn ? CoreStrings.text("Filter on") : CoreStrings.text("Filter off")
        }
    }

    /// The whole line as one text, for VoiceOver.
    public var text: String {
        guard !states.isEmpty else { return values }
        let words = states.map(word).joined(separator: " / ")
        return values.isEmpty ? words : values + " · " + words
    }
}

extension ConsoleMirror {
    /// Detector, Envelope, Comp position and the key: the comp settings nobody rides.
    public func compFold(_ strip: StripID, locale: Locale = .current) -> FoldedLine {
        let dynamics = Catalog.dynamics(strip)
        var names = [CoreStrings.text("Detector"), CoreStrings.text("Envelope")]
        var values = [shown(dynamics.detector, locale), shown(dynamics.envelope, locale)]
        if let position = Catalog.dynamicsPosition(strip) {
            names.append(CoreStrings.text("Position"))
            values.append(named(position, locale))
        }
        names.append(CoreStrings.text("Key"))
        return keyFold(names: names, values: values, key: Catalog.dynamicsKey(strip), locale)
    }

    public func gateKeyFold(_ strip: StripID, locale: Locale = .current) -> FoldedLine {
        keyFold(names: [CoreStrings.text("Key")], values: [], key: Catalog.gateKey(strip), locale)
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

    /// The key's source (a matrix's or main's comp has none), then "Filter on" or "Filter off" as the line's state
    /// (Slim, 2026-10-31): what changes when the gate or comp acts. The filter's type and frequency stay in the sheet.
    private func keyFold(names: [String], values: [String], key: KeySpecs, _ locale: Locale) -> FoldedLine {
        var values = values
        if let source = key.sourceAddress { values.append(shown(Catalog.keySource(source, rawName: rawName), locale)) }
        let isOn = normalized(key.filterOn).map { $0 >= 0.5 }
        if isOn == nil { values.append("—") }
        return FoldedLine(
            names: names.joined(separator: " · "), values: values.joined(separator: " · "),
            states: isOn.map { [$0] } ?? [], subject: .keyFilter)
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

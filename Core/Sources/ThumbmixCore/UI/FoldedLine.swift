import Foundation

/// The one line a set-once block folds into (mocks 2026-10-20-fewer-options): what's inside, over its values.
/// A tap opens the block in a sheet, so the tab never changes length.
public struct FoldedLine: Equatable, Sendable {
    public let names: String
    public let values: String

    public init(names: String, values: String) {
        self.names = names
        self.values = values
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
        var names = [CoreStrings.text("Insert")]
        if blocks.count > 1 { names.append(blocks.map { name($0[0]) }.joined(separator: " / ")) }
        names.append(perBlock(blocks) { self.insertSpec($0).map { self.named($0.position, locale) } ?? "—" })
        return FoldedLine(names: names.joined(separator: " · "), values: insertValues(blocks, sides: sides, locale))
    }

    /// "Comp · Vox 1". A linked pair reads as one, unless the tab shows one side of a section the desk doesn't link.
    public func sheetTitle(_ section: String, strip: StripID, perSide: Bool) -> String {
        section + " · " + (perSide || !isLinked(strip) ? name(strip) : pairName(strip))
    }

    private func insertValues(_ blocks: [[StripID]], sides: [StripID], _ locale: Locale) -> String {
        if sides.compactMap(insertSlot).allSatisfy({ $0 == .none }) {
            return CoreStrings.text("No slot picked on the desk")
        }
        let state = perBlock(blocks) { self.insertSpec($0).map { self.shown($0.on, locale) } ?? "—" }
        return (insertLabel(sides) ?? "—") + " · " + state
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
        case true?: parts.append(shown(key.filterType, locale) + " " + shown(key.filterFrequency, locale))
        case false? where parts.isEmpty: parts.append(CoreStrings.text("Filter off"))
        case false?: break
        case nil: parts.append("—")
        }
        return parts.joined(separator: " · ")
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

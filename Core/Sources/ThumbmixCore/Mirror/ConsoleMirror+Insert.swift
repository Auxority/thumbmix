import Foundation

/// What the Mix tab's Insert block shows: only values the desk sent (safety rule).
extension ConsoleMirror {
    public func insertSlot(_ strip: StripID) -> InsertSlot? {
        guard let spec = Catalog.insert(strip), case .int(let sel)? = cell(spec.slot.address).argument else { return nil }
        return InsertSlot(sel: Int(sel))
    }

    public func effectName(fx: Int) -> String? {
        guard case .int(let type)? = cell(Catalog.fxType(fx)).argument else { return nil }
        return FXEffects.name(fx: fx, type: Int(type))
    }

    /// One strip's slot, or a linked pair's (odd side first); nil until every side's slot was read.
    public func insertLabel(_ sides: [StripID]) -> String? {
        let slots = sides.compactMap(insertSlot)
        guard slots.count == sides.count, let first = slots.first else { return nil }
        if slots.count == 2 { return InsertSlot.pairLabel(first, slots[1]) { effectName(fx: $0) } }
        return first.label(effect: first.fx.flatMap { effectName(fx: $0) })
    }

    /// True once every side's slot, On and Position came from the desk: until then the block's controls stay disabled.
    public func isInsertRead(_ sides: [StripID]) -> Bool {
        sides.allSatisfy { side in
            guard let spec = Catalog.insert(side) else { return false }
            return insertSlot(side) != nil && cell(spec.on.address).argument != nil
                && cell(spec.position.address).argument != nil
        }
    }

    /// A pair shows one block while the desk links inserts too and the read On and Position agree, else one per
    /// side. The slot isn't compared: a pair normally holds FX5 L and FX5 R. `partner` is the Mix tab's pan partner:
    /// nil for a single strip, or for a pair already shown one side at a time.
    public func insertBlocks(_ strip: StripID, partner: StripID?) -> [[StripID]] {
        guard let partner else { return [[strip]] }
        let differs = sidesDiffer(strip, partner, \.on) || sidesDiffer(strip, partner, \.position)
        return isShared(.dynamics) && !differs ? [[strip, partner]] : [[strip], [partner]]
    }

    /// Both sides' cells were read and hold different values; an unread side never counts as a difference.
    private func sidesDiffer(_ a: StripID, _ b: StripID, _ param: KeyPath<InsertSpecs, ParamSpec>) -> Bool {
        guard let specA = Catalog.insert(a), let specB = Catalog.insert(b),
            let valueA = cell(specA[keyPath: param].address).argument,
            let valueB = cell(specB[keyPath: param].address).argument
        else { return false }
        return valueA != valueB
    }
}

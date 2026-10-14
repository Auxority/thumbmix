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

    /// A pair whose fader the desk links shows one block while it links inserts too, else one per side. `partner`
    /// is the Mix tab's pan partner: nil for a single strip, or for a pair already shown one side at a time.
    public func insertBlocks(_ strip: StripID, partner: StripID?) -> [[StripID]] {
        guard let partner else { return [[strip]] }
        return isShared(.dynamics) ? [[strip, partner]] : [[strip], [partner]]
    }
}

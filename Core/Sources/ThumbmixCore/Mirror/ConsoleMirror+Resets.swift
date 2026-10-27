import Foundation

/// The tabs' Reset buttons. Each writes through `set`, so a linked pair's partner follows as for any edit, and an
/// unread control is left alone.
extension ConsoleMirror {
    /// Puts every band back to `Catalog.eqDefaults`; a no-op on strips without defaults.
    public func resetEQBands(_ strip: StripID) {
        for index in (Catalog.eqDefaults(strip) ?? []).indices { resetEQBand(strip, index + 1) }
    }

    public func resetEQBand(_ strip: StripID, _ band: Int) {
        for (address, argument) in Catalog.eqDefaultArguments(strip, band) { set(address, argument) }
    }

    public func resetGate(_ strip: StripID) {
        setAll(Catalog.gateDefaults(strip))
    }

    public func resetDynamics(_ strip: StripID) {
        setAll(Catalog.dynamicsDefaults(strip))
    }

    /// The preamp's gain too, which every channel on that input shares: the button's alert names them.
    public func resetInput(_ strip: StripID) {
        setAll(Catalog.inputDefaults(strip, headamp: headamp(of: strip)))
    }

    /// Whom a tab's Reset alert names: the pair, as the screen's title does, when the desk links that tab's section,
    /// so the reset reaches both sides; else the strip itself (mock A, 2026-10-27).
    public func resetName(_ tab: ChannelTab, of strip: StripID) -> String {
        guard isLinked(strip), let section = tab.linkSection, isShared(section) else { return name(strip) }
        return pairName(strip)
    }

    /// false until the desk sent every value `tab`'s Reset writes, and which preamp feeds the strip: `set` skips an
    /// unread control, so an earlier tap would reset only part of what the alert promised.
    public func isReadForReset(_ tab: ChannelTab, of strip: StripID) -> Bool {
        resetAddresses(tab, of: strip).allSatisfy { cell($0).argument != nil }
    }

    private func resetAddresses(_ tab: ChannelTab, of strip: StripID) -> [String] {
        switch tab {
        case .eq:
            (Catalog.eqDefaults(strip) ?? []).indices.flatMap { Catalog.eqBand(strip, $0 + 1).all.map(\.address) }
        case .gate: Catalog.gateDefaults(strip).map(\.spec.address)
        case .comp: Catalog.dynamicsDefaults(strip).map(\.spec.address)
        case .input:
            [Catalog.headampIndex(strip)].compactMap { $0 }
                + Catalog.inputDefaults(strip, headamp: headamp(of: strip)).map(\.spec.address)
        case .mix, .members, .sends, .fedBy: []
        }
    }

    private func setAll(_ defaults: [(spec: ParamSpec, value: Double)]) {
        for (address, argument) in Catalog.deskArguments(defaults) { set(address, argument) }
    }
}

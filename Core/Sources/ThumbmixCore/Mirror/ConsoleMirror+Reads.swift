/// Reads beyond the overview (2026-10-12): an opened tab first, then the tabs of strips in use in the background.
/// Unread values show no number and can't be set, so a tab still being read is dimmed, never guessed.
extension ConsoleMirror {
    /// Reads what `tab` shows of `strip`, and of its linked partner, ahead of the background fill. Ignored until live:
    /// a resync forgets these values, and the screen asks again once live.
    public func read(_ tab: ChannelTab, of strip: StripID) {
        guard isLive else { return }
        reads.add(unread(tab, [strip] + linkedPartner(of: strip)), urgent: true)
        pumpReads()
    }

    /// The tabs of every strip worth prefetching, one tab across all of them before the next, in `ChannelTab.fillOrder`.
    func startBackgroundFill() {
        let strips = stripsWorthPrefetching()
        for tab in ChannelTab.fillOrder {
            reads.add(unread(tab, strips.filter { ChannelTab.tabs(for: $0.kind).contains(tab) }), urgent: false)
        }
    }

    /// Strips worth prefetching, plus their linked partners: a pair is read as a whole.
    private func stripsWorthPrefetching() -> [StripID] {
        let used = StripKind.allCases.flatMap(StripID.all).filter(isWorthPrefetching)
        var seen = Set<StripID>()
        return (used + used.flatMap { linkedPartner(of: $0) }).filter { seen.insert($0).inserted }
    }

    /// The background fill's policy, not the overview's fold (`isUnused`): named and fader up (the user, 2026-10-12).
    /// A named spare with its fader down waits until it's opened.
    private func isWorthPrefetching(_ strip: StripID) -> Bool {
        !rawName(strip).isEmpty && (normalized(Catalog.fader(strip)) ?? 0) > 0
    }

    private func unread(_ tab: ChannelTab, _ strips: [StripID]) -> [String] {
        strips.flatMap { Catalog.tabAddresses(tab, $0, headamp: headamp(of: $0)) }.filter { cell($0).argument == nil }
    }

    private func linkedPartner(of strip: StripID) -> [StripID] {
        isLinked(strip) ? [strip.partner].compactMap { $0 } : []
    }
}

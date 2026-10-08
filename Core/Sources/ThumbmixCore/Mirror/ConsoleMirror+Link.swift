import Foundation

/// What the mirror knows about stereo pairs. The desk copies an edit of a shared section to the partner itself,
/// so the app writes one side and re-reads the other (see `set`).
extension ConsoleMirror {
    public func isLinked(_ strip: StripID) -> Bool {
        guard let address = strip.linkAddress else { return false }
        return cell(address).argument == .int(1)
    }

    /// The side that a Gain/Delay change (gain, 48V, trim, delay) also reaches on the desk; nil when the strip isn't
    /// linked or the preference keeps the sides apart. Whether 48V follows too is unverified (m32-probe section 7).
    public func gainDelayPartner(of strip: StripID) -> StripID? {
        guard isLinked(strip), isShared(.gainDelay) else { return nil }
        return strip.partner
    }

    /// Unread counts as separate: each side then shows its own value, which is never wrong. So does a section whose
    /// partner didn't follow the app's edit, whatever the preference says.
    public func isShared(_ section: LinkSection) -> Bool {
        cell(section.preferenceAddress).argument == .int(1) && !sectionsSeenUnlinked.contains(section)
    }

    /// Fader, mute and sends are seen linked on the desk, so a partner left behind means the desk doesn't copy OSC
    /// edits: it is put right and both sides are written from then on. Every other section is unverified (m32-probe
    /// section 7): it is shown per side instead, and nothing is written.
    func partnerDidNotFollow(_ address: String, wanted: OSCArgument, section: LinkSection) {
        guard section == .faderMute else {
            sectionsSeenUnlinked.insert(section)
            return
        }
        linkCopies.deskCopies = false
        write(address, wanted)
    }

    func linkSection(of address: String) -> LinkSection? {
        if address.hasPrefix("/headamp/") { return .gainDelay }
        return StripID.linkable(from: address).flatMap { LinkSection.of(suffix: $0.suffix) }
    }

    /// The section a linked pair's tab must show per side, because the desk doesn't link it; nil shows it once.
    public func unlinkedSection(of tab: ChannelTab, for strip: StripID) -> LinkSection? {
        guard isLinked(strip), let section = tab.linkSection, !isShared(section) else { return nil }
        return section
    }

    public func pairName(_ strip: StripID) -> String {
        let odd = strip.oddSide
        let even = odd.partner ?? odd
        return PairName.make(odd: rawName(odd), even: rawName(even), fallback: strip.pairDefaultName)
    }

    public func setLinked(_ strip: StripID, _ linked: Bool) {
        guard let address = strip.linkAddress else { return }
        set(address, .int(linked ? 1 : 0))
        rereadPair(strip.oddSide)
    }

    /// A link or Link Preference that changed, here or on the desk, decides what the screens show next.
    func linkSettingChanged(_ address: String) {
        if let section = LinkSection.allCases.first(where: { $0.preferenceAddress == address }) {
            sectionsSeenUnlinked.remove(section)
        } else if let odd = Self.pairsByLinkAddress[address] {
            rereadPair(odd)
        }
    }

    /// Linking pans the sides apart and may copy the odd side's settings, and the desk may not push any of it:
    /// both strips are read back, spread out so the desk isn't flooded.
    private func rereadPair(_ odd: StripID) {
        let addresses = [odd, odd.partner].compactMap { $0 }.flatMap(Catalog.addresses(of:))
        for (index, address) in addresses.enumerated() {
            holds.rereadSoon(address, now: .now + .milliseconds(5 * index))
        }
    }

    private static let pairsByLinkAddress = Dictionary(
        uniqueKeysWithValues: StripKind.allCases.flatMap(StripID.all).filter { $0 == $0.oddSide }
            .compactMap { odd in odd.linkAddress.map { ($0, odd) } })

    /// The partner's copy of `address` when the desk copies this edit to it; nil otherwise.
    func partnerAddress(of address: String) -> String? {
        if address.hasPrefix("/headamp/") { return partnerHeadampAddress(of: address) }
        guard let (strip, suffix) = StripID.linkable(from: address), let section = LinkSection.of(suffix: suffix),
            isShared(section), isLinked(strip), let partner = strip.partner
        else { return nil }
        return partner.prefix + suffix
    }

    /// "/headamp/040/gain" → the same parameter on the headamp feeding the linked partner input. A headamp feeding
    /// several inputs can't say which pair the edit is for, so it gets no partner.
    private func partnerHeadampAddress(of address: String) -> String? {
        let parts = address.split(separator: "/", maxSplits: 2)
        guard isShared(.gainDelay), parts.count == 3, let index = Int(parts[1]) else { return nil }
        let inputs = (1...32).filter { headamp(forInput: $0) == index }
        guard inputs.count == 1, let input = inputs.first,
            isLinked(StripID(.input, input)), let partner = StripID(.input, input).partner,
            let partnerIndex = headamp(forInput: partner.number), partnerIndex != index
        else { return nil }
        return "/headamp/" + String(format: "%03d", partnerIndex) + "/" + parts[2]
    }
}

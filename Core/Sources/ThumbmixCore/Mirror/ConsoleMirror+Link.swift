import Foundation

/// What the mirror knows about stereo pairs. The desk copies an edit of a shared section to the partner itself,
/// so the app writes one side and re-reads the other (see `set`).
extension ConsoleMirror {
    public func isLinked(_ strip: StripID) -> Bool {
        guard let address = strip.linkAddress else { return false }
        return cell(address).argument == .int(1)
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

    public func pairName(_ strip: StripID) -> String {
        let odd = strip.oddSide
        let even = odd.partner ?? odd
        return PairName.make(odd: rawName(odd), even: rawName(even), fallback: strip.pairDefaultName)
    }

    /// Linking makes the desk pan the sides hard left and right, so both pans are read back afterwards.
    public func setLinked(_ strip: StripID, _ linked: Bool) {
        guard let address = strip.linkAddress else { return }
        set(address, .int(linked ? 1 : 0))
        for side in [strip.oddSide, strip.oddSide.partner].compactMap({ $0 }) {
            if let pan = side.pan { holds.rereadSoon(pan, now: .now) }
        }
    }

    /// The partner's copy of `address` when the desk copies this edit to it; nil otherwise.
    func partnerAddress(of address: String) -> String? {
        if address.hasPrefix("/headamp/") { return partnerHeadampAddress(of: address) }
        guard let (strip, suffix) = StripID.linkable(from: address), let section = LinkSection.of(suffix: suffix),
            isShared(section), isLinked(strip), let partner = strip.partner
        else { return nil }
        return partner.prefix + suffix
    }

    /// "/headamp/040/gain" → the same parameter on the headamp feeding the linked partner input.
    private func partnerHeadampAddress(of address: String) -> String? {
        let parts = address.split(separator: "/", maxSplits: 2)
        guard isShared(.gainDelay), parts.count == 3, let index = Int(parts[1]),
            let input = (1...32).first(where: { headamp(forInput: $0) == index }),
            isLinked(StripID(.input, input)), let partner = StripID(.input, input).partner,
            let partnerIndex = headamp(forInput: partner.number), partnerIndex != index
        else { return nil }
        return "/headamp/" + String(format: "%03d", partnerIndex) + "/" + parts[2]
    }
}

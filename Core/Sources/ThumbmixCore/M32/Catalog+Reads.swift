import Foundation

/// What the mirror reads, and when (2026-10-12): the overview on connect, a tab's values when it opens, and the tabs
/// of strips in use in the background. Reading everything on connect took ~5 s at a 5 ms round trip; this ~0.6 s.
extension Catalog {
    /// Read on connect; the mirror goes live once all have answered. Also what decides how strips and tabs look.
    public static func overviewAddresses() -> [String] { overview }

    /// Every address the app ever reads: the overview, and every tab of every strip with every preamp.
    public static func allAddresses() -> [String] { all }

    // Built once: every mirror and every fake desk asks for them, and building all took ~30 ms (debug). A test run
    // starting ~100 of each at once starved the main actor for seconds on CI.
    private static let overview: [String] =
        StripKind.allCases.flatMap(StripID.all).flatMap(overviewAddresses(of:)) + headampIndexAddresses
        + rtaAddresses + linkAddresses + [exclusiveSolo]

    private static let all: [String] = {
        let tabs = StripKind.allCases.flatMap(StripID.all).flatMap { strip in
            ChannelTab.tabs(for: strip.kind).flatMap { tabAddresses($0, strip, headamp: nil) }
        }
        var seen = Set<String>()
        return (overview + tabs + headampAddresses()).filter { seen.insert($0).inserted }
    }()

    /// Every pair's link switch and the four Link Preferences: they decide how the overview and tabs look.
    public static let linkAddresses =
        StripKind.allCases.flatMap(StripID.all).filter(\.isOddSide).compactMap(\.linkAddress)
        + LinkSection.allCases.map(\.preferenceAddress)

    /// Exclusive solo (doc p.21): each solo replaces the last. Read on connect, so a stroke knows to ask first.
    public static let exclusiveSolo = "/config/solo/exclusive"

    /// Read on connect so the desk's own RTA setting is known before the app borrows it.
    static let rtaAddresses = [RTA.source, RTA.position]

    /// What `tab` shows of `strip` beyond the overview. `headamp` is the preamp the desk says feeds the strip: the
    /// Input tab shows its gain and 48V.
    public static func tabAddresses(_ tab: ChannelTab, _ strip: StripID, headamp: Int?) -> [String] {
        switch tab {
        case .mix:
            [strip.mainLR].compactMap { $0 } + (insert(strip)?.all.map(\.address) ?? [])
                + (strip.hasInsert ? fxTypeAddresses : [])
        case .members: []
        case .input: inputAddresses(strip, headamp: headamp)
        case .gate: strip.hasGate ? gate(strip).all.map(\.address) + gateKey(strip).addresses : []
        case .eq: eqAddresses(strip)
        case .comp: dynamicsAddresses(strip)
        case .sends: sendAddresses(strip) + [dynamicsPosition(strip)?.address].compactMap { $0 }
        case .fedBy:
            // The rows' values first, so they light up before the sheets' (read in the same batch).
            strip.kind.feeders.flatMap(StripID.all).flatMap {
                [feedOn(from: $0, to: strip).address, feedLevel(from: $0, to: strip).address]
            } + strip.kind.feeders.flatMap(StripID.all).flatMap { sendSheetAddresses(from: $0, to: strip) }
        }
    }

    /// What a Fed by row's send sheet shows: both sends of the pair, which share its tap and pans, and where the
    /// source's comp sits (the tap chain). Nothing for the mains, which have no sheet.
    private static func sendSheetAddresses(from source: StripID, to target: StripID) -> [String] {
        let odd = target.oddSide
        guard sendTap(from: source, to: odd) != nil else { return [] }
        return odd.pairSides.flatMap { levelAndOn(from: source, to: $0) }
            + settings(from: source, to: odd) + [dynamicsPosition(source)?.address].compactMap { $0 }
    }

    /// Everything one strip shows: its overview values and every tab's.
    public static func addresses(of strip: StripID, headamp: Int?) -> [String] {
        overviewAddresses(of: strip) + ChannelTab.tabs(for: strip.kind).flatMap { tabAddresses($0, strip, headamp: headamp) }
    }

    private static func overviewAddresses(of strip: StripID) -> [String] {
        // Solo too: S sits beside the slim fader on every tab, and an unread switch ignores taps.
        [strip.name, strip.color, strip.icon, strip.fader, strip.on, strip.solo]
            + [strip.pan, strip.dcaMask].compactMap { $0 }
    }

    private static func inputAddresses(_ strip: StripID, headamp: Int?) -> [String] {
        let preamp = headamp.map { [headampGain($0).address, headampPhantom($0).address] } ?? []
        return [trim(strip).address] + [invert(strip)?.address].compactMap { $0 } + preamp
            + (delay(strip)?.all.map(\.address) ?? [])
    }

    /// The sends' taps and switches too: moving the comp asks first when a send tapped around the EQ would change.
    private static func dynamicsAddresses(_ strip: StripID) -> [String] {
        guard strip.hasDynamics else { return [] }
        let sends = strip.kind.sendTarget.map(StripID.all) ?? []
        return dynamics(strip).all.map(\.address) + dynamicsKey(strip).addresses
            + [dynamicsPosition(strip)?.address].compactMap { $0 }
            + sends.flatMap { [sendOn(from: strip, to: $0).address] + [sendTap(from: strip, to: $0)?.address].compactMap { $0 } }
    }

    private static func eqAddresses(_ strip: StripID) -> [String] {
        guard strip.eqBandCount > 0 else { return [] }
        return [eqOn(strip).address] + (lowCut(strip)?.all.map(\.address) ?? [])
            + (1...strip.eqBandCount).flatMap { eqBand(strip, $0).all.map(\.address) }
    }

    private static func sendAddresses(_ strip: StripID) -> [String] {
        guard let target = strip.kind.sendTarget else { return [] }
        return StripID.all(target).flatMap { levelAndOn(from: strip, to: $0) + settings(from: strip, to: $0) }
    }

    private static func levelAndOn(from strip: StripID, to target: StripID) -> [String] {
        [sendLevel(from: strip, to: target).address, sendOn(from: strip, to: target).address]
    }

    private static func settings(from strip: StripID, to target: StripID) -> [String] {
        [
            sendPan(from: strip, to: target)?.address, sendPanFollow(from: strip, to: target)?.address,
            sendTap(from: strip, to: target)?.address,
        ].compactMap { $0 }
    }
}

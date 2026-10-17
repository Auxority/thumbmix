import Foundation

/// Whether a Members row's strip is on the DCA. A linked pair is one row; the desk may hold only one side assigned.
public enum DCAAssignment: Equatable, Sendable {
    case assigned, unassigned, leftOnly, rightOnly
    /// A side's mask was never read: the chip stays disabled.
    case unread
}

/// A DCA's Members tab assigns strips by their `grp/dca` mask (mock 2026-10-17-dca-members). A tap applies at once:
/// the engineer opens this tab to change who's in (the user, 2026-10-17).
extension ConsoleMirror {
    /// The groups whose strips have a DCA mask, each under its own heading on the tab.
    public static let dcaAssignableGroups: [StripGroup] = [.inputs, .aux, .fx, .buses]

    /// Every strip with a DCA mask, in desk order.
    public static let dcaAssignableStrips = dcaAssignableGroups.flatMap(\.strips)

    /// The tab's rows for `strips`: a linked pair is one row held by its odd side, even with its faders unlinked.
    public func assignmentRows(_ strips: [StripID]) -> [OverviewItem] {
        strips.compactMap { strip in
            guard isLinked(strip), strip.partner != nil else { return .strip(strip, .full) }
            return strip.isOddSide ? .pair(strip) : nil
        }
    }

    public func dcaAssignment(of strip: StripID, to dca: Int) -> DCAAssignment {
        let sides = assignmentSides(of: strip)
        guard sides.allSatisfy({ dcaMask(of: $0) != nil }) else { return .unread }
        switch sides.map({ isMember($0, ofDCA: dca) }) {
        case [true, false]: return .leftOnly
        case [false, true]: return .rightOnly
        case let assigned: return assigned.allSatisfy { $0 } ? .assigned : .unassigned
        }
    }

    /// Assigned becomes unassigned; unassigned or half assigned becomes assigned on both sides. Each side keeps its
    /// other DCAs' bits.
    public func toggleDCAAssignment(of strip: StripID, to dca: Int) {
        let assignment = dcaAssignment(of: strip, to: dca)
        guard assignment != .unread else { return }
        let bit = Int32(1) << (dca - 1)
        for side in assignmentSides(of: strip) {
            guard let address = side.dcaMask, let mask = dcaMask(of: side) else { continue }
            set(address, .int(assignment == .assigned ? mask & ~bit : mask | bit))
        }
    }

    /// The unused strips the tab folds away; an assigned one stays in view, and a pair stays while either side is in.
    public func unusedStrips(notAssignedTo dca: Int) -> [StripID] {
        unusedStrips(Self.dcaAssignableStrips) { isUnused($0) && !isMember($0, ofDCA: dca) }
    }

    /// The doc doesn't say whether the desk links DCA assignment; half a stereo source on a DCA is never wanted, so a
    /// linked pair writes both sides, as Solo does.
    private func assignmentSides(of strip: StripID) -> [StripID] {
        isLinked(strip) ? strip.pairSides : [strip]
    }

    private func dcaMask(of strip: StripID) -> Int32? {
        guard let address = strip.dcaMask, case .int(let mask)? = cell(address).argument else { return nil }
        return mask
    }
}

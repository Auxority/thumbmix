import Foundation

/// What a strip can be in: a DCA (`grp/dca`, 8 bits) or a mute group (`grp/mute`, 6 bits).
public enum Membership: Hashable, Sendable {
    case dca(Int)
    case muteGroup(Int)

    /// The strip's mask for this kind of group; nil where the strip has none (a DCA in a DCA or mute group).
    public func mask(of strip: StripID) -> String? {
        switch self {
        case .dca: strip.dcaMask
        case .muteGroup: strip.muteGroupMask
        }
    }

    /// Bit 0 = DCA 1 or mute group 1. The doc states neither bit order; m32-probe sections 4 and 11 check them.
    public var bit: Int32 {
        switch self {
        case .dca(let number), .muteGroup(let number): Int32(1) << (number - 1)
        }
    }
}

/// Whether a Members row's strip is in the group. A linked pair is one row; the desk may hold only one side in.
public enum Assignment: Equatable, Sendable {
    case assigned, unassigned, leftOnly, rightOnly
    /// A side's mask was never read: the chip stays disabled.
    case unread
}

/// A DCA's Members tab assigns strips by their `grp/dca` mask (mock 2026-10-17-dca-members), a mute group's members
/// screen by `grp/mute`. A tap applies at once: the engineer opens these to change who's in (the user, 2026-10-17).
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

    public func assignment(of strip: StripID, to group: Membership) -> Assignment {
        let sides = assignmentSides(of: strip)
        guard sides.allSatisfy({ mask(of: $0, for: group) != nil }) else { return .unread }
        switch sides.map({ isMember($0, of: group) }) {
        case [true, false]: return .leftOnly
        case [false, true]: return .rightOnly
        case let assigned: return assigned.allSatisfy { $0 } ? .assigned : .unassigned
        }
    }

    /// Assigned becomes unassigned; unassigned or half assigned becomes assigned on both sides. Each side keeps its
    /// other groups' bits.
    public func toggleAssignment(of strip: StripID, to group: Membership) {
        let assignment = assignment(of: strip, to: group)
        guard assignment != .unread else { return }
        for side in assignmentSides(of: strip) {
            guard let address = group.mask(of: side), let mask = mask(of: side, for: group) else { continue }
            set(address, .int(assignment == .assigned ? mask & ~group.bit : mask | group.bit))
        }
    }

    /// false until the strip's mask was read.
    public func isMember(_ strip: StripID, of group: Membership) -> Bool {
        guard let mask = mask(of: strip, for: group) else { return false }
        return mask & group.bit != 0
    }

    /// The unused strips the tab folds away; an assigned one stays in view, and a pair stays while either side is in.
    public func unusedStrips(notIn group: Membership) -> [StripID] {
        unusedStrips(Self.assignableStrips(group)) { isUnused($0) && !isMember($0, of: group) }
    }

    /// Every strip with a mask for `group`'s kind, in desk order.
    public static func assignableStrips(_ group: Membership) -> [StripID] {
        switch group {
        case .dca: dcaAssignableStrips
        case .muteGroup: muteGroupAssignableStrips
        }
    }

    /// The doc doesn't say whether the desk links DCA or mute group assignment; half a stereo source in a group is
    /// never wanted, so a linked pair writes both sides, as Solo does.
    func assignmentSides(of strip: StripID) -> [StripID] {
        isLinked(strip) ? strip.pairSides : [strip]
    }

    private func mask(of strip: StripID, for group: Membership) -> Int32? {
        guard let address = group.mask(of: strip), case .int(let mask)? = cell(address).argument else { return nil }
        return mask
    }
}

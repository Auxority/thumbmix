import Foundation

/// The six mute groups on the Main page, and the red-bordered M of a strip a group is muting (spec 2026-10-19).
extension ConsoleMirror {
    /// Every kind but the DCAs has a mute group mask (doc p.27-38), each under its own heading.
    public static let muteGroupAssignableGroups: [StripGroup] = [.inputs, .aux, .fx, .buses, .matrix, .main]

    public static let muteGroupAssignableStrips = muteGroupAssignableGroups.flatMap(\.strips)

    /// nil until the desk sent the group's state.
    public func isMuteGroupOn(_ group: Int) -> Bool? {
        guard case .int(let value)? = cell(Catalog.muteGroup(group)).argument else { return nil }
        return value == 1
    }

    /// Switches at once, as MUTE does; `set` ignores a group whose state was never read.
    public func toggleMuteGroup(_ group: Int) {
        set(Catalog.muteGroup(group), .int(isMuteGroupOn(group) == true ? 0 : 1))
    }

    /// In a group read as on, on either side of a linked pair: the pair's row shows one M for both. A group still
    /// unread counts neither way. Assumed: the group mute leaves the strip's own `mix/on` alone (m32-probe section 11).
    public func isMutedByGroup(_ strip: StripID) -> Bool {
        let sides = isLinked(strip) ? strip.pairSides : [strip]
        let onGroups = (1...Catalog.muteGroupCount).filter { isMuteGroupOn($0) == true }
        return sides.contains { side in onGroups.contains { isMember(side, of: .muteGroup($0)) } }
    }

    /// The group's members by the names their overview rows show, a linked pair once, in desk order.
    public func muteGroupMemberNames(_ group: Int) -> [String] {
        let members = Self.muteGroupAssignableStrips.filter { strip in
            assignmentSides(of: strip).contains { isMember($0, of: .muteGroup(group)) }
        }
        return assignmentRows(members).map(title(of:))
    }

    /// Asks the desk again for every group's state: whether `/xremote` pushes a group switched on the desk is
    /// unverified (m32-probe section 11), so the Main page re-reads them each time it opens. Ignored until live.
    public func readMuteGroups() {
        guard isLive else { return }
        reads.add(Catalog.muteGroupAddresses, urgent: true)
        pumpReads()
    }
}

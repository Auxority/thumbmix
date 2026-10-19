/// What a strip's edit sheet has ticked, as a draft sent with the name on Done (spec 2026-10-19 §4): only the groups
/// the engineer changed, so Done can't undo a change made on the desk while the sheet was open.
public struct MembershipDraft: Equatable, Sendable {
    private var wanted: [Membership: Bool] = [:]

    public init() {}

    public var isEmpty: Bool { wanted.isEmpty }

    /// In becomes out; out or half in becomes in on both sides, as the Members tab does. Back to what the desk holds
    /// drops the change. An unread mask ignores the tap.
    public mutating func toggle(_ group: Membership, current: Assignment) {
        guard current != .unread else { return }
        let wantsIn = shown(group, current: current) != .assigned
        let unchanged = wantsIn ? current == .assigned : current == .unassigned
        wanted[group] = unchanged ? nil : wantsIn
    }

    public func shown(_ group: Membership, current: Assignment) -> Assignment {
        guard let wantsIn = wanted[group] else { return current }
        return wantsIn ? .assigned : .unassigned
    }

    /// The groups the strip joins, to warn about one that's on.
    var joined: [Membership] { wanted.filter(\.value).map(\.key) }

    func wants(_ group: Membership) -> Bool? { wanted[group] }

    var groups: [Membership] { Array(wanted.keys) }
}

extension ConsoleMirror {
    /// The sheet's sections: DCAs where the strip has a DCA mask, mute groups where it has a mute group mask.
    public static func groupChoices(for strip: StripID) -> (dcas: [Membership], muteGroups: [Membership]) {
        (
            strip.dcaMask == nil ? [] : (1...8).map { .dca($0) },
            strip.muteGroupMask == nil ? [] : (1...Catalog.muteGroupCount).map { .muteGroup($0) }
        )
    }

    /// Done: per side and mask, one set with the ticked bits changed on the mask as the desk holds it now.
    public func apply(_ draft: MembershipDraft, to strip: StripID) {
        for side in assignmentSides(of: strip) {
            let byMask = Dictionary(grouping: draft.groups) { $0.mask(of: side) }
            for case (let address?, let groups) in byMask {
                guard case .int(var mask)? = cell(address).argument else { continue }
                for group in groups { mask = draft.wants(group) == true ? mask | group.bit : mask & ~group.bit }
                set(address, .int(mask))
            }
        }
    }

    /// The mute groups the draft adds the strip to that are on now: Done mutes the strip there and then.
    public func mutesOnDone(_ draft: MembershipDraft, of strip: StripID) -> [Int] {
        draft.joined.compactMap { group -> Int? in
            guard case .muteGroup(let number) = group, assignment(of: strip, to: group) != .assigned,
                isMuteGroupOn(number) == true
            else { return nil }
            return number
        }
        .sorted()
    }
}

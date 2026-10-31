import Foundation

/// Where a mute group's name shows (spec 2026-10-31-mute-group-names): the Main page's button, the members page, the
/// red-bordered M's VoiceOver, a strip row's caption and the edit sheet's Groups. Unnamed groups keep their number.
extension ConsoleMirror {
    public func muteGroupName(_ group: Int) -> String? { muteGroupNames.name(of: group) }

    /// Stored by the app per console (`onMuteGroupNamesChanged`); the desk never sees it, so it works while offline.
    public func renameMuteGroup(_ group: Int, to text: String) {
        var names = muteGroupNames
        names.set(text, for: group)
        guard names != muteGroupNames else { return }
        muteGroupNames = names
        onMuteGroupNamesChanged?(names)
    }

    /// "Band", or "Group 2" while unnamed.
    public func muteGroupTitle(_ group: Int) -> String {
        muteGroupName(group) ?? CoreStrings.text("Group \(group)")
    }

    /// "Group 2 (Band)", or "Group 2" while unnamed.
    public func muteGroupLine(_ group: Int) -> String {
        guard let name = muteGroupName(group) else { return CoreStrings.text("Group \(group)") }
        return CoreStrings.text("Group \(group) (\(name))")
    }

    /// The lowest group that's on and holds the strip (either side of a linked pair): the one its red-bordered M names.
    public func mutingGroup(of strip: StripID) -> Int? {
        let sides = isLinked(strip) ? strip.pairSides : [strip]
        return (1...Catalog.muteGroupCount).first { group in
            isMuteGroupOn(group) == true && sides.contains { isMember($0, of: .muteGroup(group)) }
        }
    }

    /// What VoiceOver adds to the red-bordered M; nil while no group mutes the strip.
    public func mutedByText(of strip: StripID) -> String? {
        guard let group = mutingGroup(of: strip) else { return nil }
        guard let name = muteGroupName(group) else { return CoreStrings.text("Muted by mute group \(group)") }
        return CoreStrings.text("Muted by \(name)")
    }

    /// A row's caption with the name of the group muting it, while that group is on and has a name: "1 · Band".
    public func rowCaption(_ base: String, of strip: StripID) -> String {
        let group = mutingGroup(of: strip).flatMap(muteGroupName)
        return [base, group].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

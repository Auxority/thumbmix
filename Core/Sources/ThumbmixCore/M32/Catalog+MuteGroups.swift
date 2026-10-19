import Foundation

/// The desk's six mute groups (doc p.21): a group that's on mutes every strip whose `grp/mute` mask holds it.
extension Catalog {
    public static let muteGroupCount = 6

    /// `/config/mute/1` … `/6`, {OFF, ON}; the doc writes the number without a leading zero.
    public static func muteGroup(_ group: Int) -> String { "/config/mute/\(group)" }

    public static let muteGroupAddresses = (1...muteGroupCount).map(muteGroup)
}

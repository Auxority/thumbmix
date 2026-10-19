/// How a strip's M looks: filled red for its own mute, a red border when only a mute group silences it (spec
/// 2026-10-19). The strip's own mute wins: it's the one its M switches.
public enum MuteLook: Equatable, Sendable {
    case off, muted, mutedByGroup
}

extension ConsoleMirror {
    public func muteLook(_ strip: StripID) -> MuteLook {
        if isMuted(strip) { return .muted }
        return isMutedByGroup(strip) ? .mutedByGroup : .off
    }
}

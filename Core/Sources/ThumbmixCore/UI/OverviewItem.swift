import Foundation

/// Which part of the colour stripe a row lights: a linked pair's sides split it, top for the odd (left) side.
public enum StripeHalf: Hashable, Sendable {
    case full, top, bottom
}

/// One overview row: a strip, or a linked pair whose faders move together (held by its odd side).
public enum OverviewItem: Hashable, Identifiable, Sendable {
    case strip(StripID, StripeHalf)
    case pair(StripID)

    public var id: String {
        switch self {
        case .strip(let strip, _): strip.prefix
        case .pair(let odd): "pair" + odd.prefix
        }
    }

    /// The strip screen the row opens: a pair's screen belongs to its odd side.
    public var opens: StripID {
        switch self {
        case .strip(let strip, .full): strip
        case .strip(let strip, _): strip.oddSide
        case .pair(let odd): odd
        }
    }
}

extension ConsoleMirror {
    /// While true, rows must not change shape: the finger owns a control.
    public var isFingerDown: Bool { holds.isFingerDown }

    /// The rows for `strips`. A pair is unused, and hidden, only when both its sides are.
    public func overviewItems(_ strips: [StripID], showUnused: Bool) -> [OverviewItem] {
        strips.compactMap { strip in
            guard isLinked(strip), let partner = strip.partner else {
                return showUnused || !isUnused(strip) ? .strip(strip, .full) : nil
            }
            guard showUnused || !(isUnused(strip) && isUnused(partner)) else { return nil }
            return pairItem(for: strip)
        }
    }

    private func pairItem(for strip: StripID) -> OverviewItem? {
        let isOdd = strip == strip.oddSide
        guard !isShared(.faderMute) else { return isOdd ? .pair(strip) : nil }
        return .strip(strip, isOdd ? .top : .bottom)
    }
}

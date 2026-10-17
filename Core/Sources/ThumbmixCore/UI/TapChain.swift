import Foundation

/// The parts of a strip a send can be taken after.
public enum TapBlock: Hashable, Sendable {
    /// `pan` and `group` both stand for Subgroup: a stereo mix's follows the channel's pan, a mono one's can't.
    case input, gate, comp, eq, fader, pan, group

    public var name: String {
        switch self {
        case .input: CoreStrings.text("Input")
        case .gate: CoreStrings.text("Gate")
        case .comp: CoreStrings.text("Comp")
        case .eq: CoreStrings.text("EQ")
        case .fader: CoreStrings.text("Fader")
        case .pan: CoreStrings.text("Pan")
        case .group: CoreStrings.text("Group")
        }
    }

    /// Lower case for the middle of a sentence; "EQ" stays as it is.
    var partName: String {
        switch self {
        case .input: CoreStrings.text("input")
        case .gate: CoreStrings.text("gate")
        case .comp: CoreStrings.text("comp")
        case .eq: CoreStrings.text("EQ")
        case .fader: CoreStrings.text("fader")
        case .pan: CoreStrings.text("pan")
        case .group: CoreStrings.text("group")
        }
    }
}

/// A send's tap point as the chain of its strip's blocks, in signal order (mock D3/S1, 2026-10-12): every block up
/// to the tap reaches the mix. Tapping a block takes the send right after it; the explanation says what that means.
public struct TapChain: Equatable, Sendable {
    public let blocks: [TapBlock]
    private let compBeforeEQ: Bool

    /// Only a channel's send can be a subgroup (doc p.26). On a stereo mix it follows the channel's pan, so the chain
    /// ends in Pan; on a mono mix in Group, so a Subgroup set on the desk doesn't look like After fader.
    public init(source: StripID, compBeforeEQ: Bool, stereoTarget: Bool) {
        let dynamics: [TapBlock] = compBeforeEQ ? [.comp, .eq] : [.eq, .comp]
        let middle = source.hasDynamics ? dynamics : [.eq]
        let subgroup: [TapBlock] = source.kind.sendTarget == .bus ? [stereoTarget ? .pan : .group] : []
        blocks = [.input] + (source.hasGate ? [.gate] : []) + middle + [.fader] + subgroup
        self.compBeforeEQ = compBeforeEQ
    }

    /// The last block the send hears. With the comp before the EQ, Pre-EQ includes it (the user, from the desk).
    public func lastBlock(_ tap: SendTap) -> TapBlock {
        switch tap {
        case .input: .input
        case .preEQ: block(before: .eq)
        case .postEQ: .eq
        case .preFader: block(before: .fader)
        case .postFader: .fader
        case .subgroup: blocks[blocks.count - 1]
        }
    }

    public func reaches(_ block: TapBlock, at tap: SendTap) -> Bool {
        guard let index = blocks.firstIndex(of: block), let last = blocks.firstIndex(of: lastBlock(tap)) else {
            return false
        }
        return index <= last
    }

    /// The send is taken right after the tapped block. A second tap on the current tap point changes nothing, so a
    /// nervous double tap can't move a monitor mix. No tap sits between the gate and a comp before the EQ.
    public func tap(afterTapping block: TapBlock, current: SendTap) -> SendTap {
        guard block != lastBlock(current) else { return current }
        switch block {
        case .input: return .input
        case .gate: return .preEQ
        case .comp: return compBeforeEQ ? .preEQ : .preFader
        case .eq: return .postEQ
        case .fader: return .postFader
        case .pan, .group: return .subgroup
        }
    }

    /// One sentence on what the tap means while mixing.
    public func explanation(_ tap: SendTap, locale: Locale = .current) -> String {
        switch tap {
        case .subgroup where blocks.contains(.pan):
            CoreStrings.text("Follows your fader and the channel’s own pan, at a fixed 0 dB: the level and pan here step aside.")
        case .subgroup:
            CoreStrings.text("Follows your fader at a fixed 0 dB: the level here steps aside.")
        case .postFader:
            CoreStrings.text("Pull your fader down and this mix drops too: the usual choice for effects.")
        case .preFader:
            CoreStrings.text("Riding your fader won’t change this mix: the usual choice for wedges and in-ears.")
        case .input, .preEQ, .postEQ:
            partial(tap, locale: locale)
        }
    }

    private func partial(_ tap: SendTap, locale: Locale) -> String {
        let heard = blocks.filter { $0 != .input && reaches($0, at: tap) }.map(\.partName)
        let missed = blocks.filter { $0 != .pan && $0 != .group && !reaches($0, at: tap) }.map(\.partName)
        let missedList = missed.formatted(.list(type: .and).locale(locale))
        guard !heard.isEmpty else {
            return CoreStrings.text("Only the raw input reaches this mix: your \(missedList) don’t.")
        }
        let heardList = heard.formatted(.list(type: .and).locale(locale))
        return switch (heard.count, missed.count) {
        case (1, 1): CoreStrings.text("The \(heardList) reaches this mix; your \(missedList) doesn’t.")
        case (1, _): CoreStrings.text("The \(heardList) reaches this mix; your \(missedList) don’t.")
        case (_, 1): CoreStrings.text("The \(heardList) reach this mix; your \(missedList) doesn’t.")
        default: CoreStrings.text("The \(heardList) reach this mix; your \(missedList) don’t.")
        }
    }

    private func block(before next: TapBlock) -> TapBlock {
        guard let index = blocks.firstIndex(of: next), index > 0 else { return .input }
        return blocks[index - 1]
    }
}

extension ConsoleMirror {
    /// The chain for `source`'s send to `target`, with the comp where the desk says it sits.
    public func tapChain(from source: StripID, to target: StripID) -> TapChain {
        let position = Catalog.dynamicsPosition(source).flatMap { cell($0.address).argument }
        return TapChain(source: source, compBeforeEQ: position == .int(0), stereoTarget: isLinked(target))
    }

    /// The desk's tap point, nil until it has been read.
    public func sendTap(from source: StripID, to target: StripID) -> SendTap? {
        guard let spec = Catalog.sendTap(from: source, to: target), case .int(let value)? = cell(spec.address).argument
        else { return nil }
        return SendTap(rawValue: Int(value))
    }

    /// The mixes whose sound changes when `source`'s comp moves across its EQ (mock b1, 2026-10-14): sends switched
    /// on and tapped just before or after the EQ, a linked pair once. A fader tap hears the comp either way. nil until
    /// every tap and switch has been read: an unread one mustn't pass for "no mix changes".
    public func mixesChangedByMovingComp(of source: StripID) -> [String]? {
        let pairs = (source.kind.sendTarget.map(StripID.all) ?? []).filter(\.isOddSide)
        let changed = pairs.map { mixesChanged(from: source, pair: $0) }
        return changed.contains(nil) ? nil : changed.flatMap { $0 ?? [] }
    }

    /// The desk keeps one tap point per pair of mixes, on the odd send (p.26); each side has its own switch.
    private func mixesChanged(from source: StripID, pair odd: StripID) -> [String]? {
        let sides = odd.pairSides
        let switches = sides.map { cell(Catalog.sendOn(from: source, to: $0).address).argument }
        guard let tap = sendTap(from: source, to: odd), !switches.contains(nil) else { return nil }
        let heard = zip(sides, switches).filter { $0.1 == .int(1) }.map(\.0)
        guard [.preEQ, .postEQ].contains(tap), !heard.isEmpty else { return [] }
        return isLinked(odd) ? [pairName(odd)] : heard.map(name)
    }
}

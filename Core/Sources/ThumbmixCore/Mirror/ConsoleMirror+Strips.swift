import Foundation

public extension ConsoleMirror {
    func name(_ strip: StripID) -> String {
        let name = rawName(strip)
        return name.isEmpty ? strip.defaultName : name
    }

    func color(_ strip: StripID) -> ConsoleColor {
        guard case let .int(index)? = cell(strip.color).argument else { return ConsoleColor(index: 0) }
        return ConsoleColor(index: Int(index))
    }

    func normalized(_ spec: ParamSpec) -> Float? {
        cell(spec.address).argument.flatMap(spec.scale.normalized(from:))
    }

    func isMuted(_ strip: StripID) -> Bool {
        cell(strip.on).argument == .int(0)
    }

    /// Unnamed and pulled all the way down: almost certainly not patched for this show.
    func isUnused(_ strip: StripID) -> Bool {
        rawName(strip).isEmpty && (normalized(Catalog.fader(strip)) ?? 0) == 0
    }

    /// The headamp (0-127) feeding input `n`, or nil when it reads from an internal source.
    func headamp(forInput n: Int) -> Int? {
        guard case let .int(index)? = cell(Catalog.headampIndex(forInput: n)).argument, (0...127).contains(index) else { return nil }
        return Int(index)
    }

    func inputsSharingHeadamp(withInput n: Int) -> [Int] {
        guard let mine = headamp(forInput: n) else { return [] }
        return (1...32).filter { $0 != n && headamp(forInput: $0) == mine }
    }

    /// Bit 0 = DCA 1. The doc doesn't state the bit order; m32-probe section 4 checks it.
    func isMember(_ strip: StripID, ofDCA dca: Int) -> Bool {
        guard let address = strip.dcaMask, case let .int(mask)? = cell(address).argument else { return false }
        return mask & (1 << (dca - 1)) != 0
    }

    func dcaMembers(_ dca: Int) -> [StripID] {
        [StripKind.input, .auxIn, .fxReturn, .bus].flatMap(StripID.all).filter { isMember($0, ofDCA: dca) }
    }

    private func rawName(_ strip: StripID) -> String {
        guard case let .string(name)? = cell(strip.name).argument else { return "" }
        return name.trimmingCharacters(in: .whitespaces)
    }
}

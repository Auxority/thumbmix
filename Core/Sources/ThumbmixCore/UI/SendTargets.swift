extension ConsoleMirror {
    /// The rows of `strip`'s Sends tab, in pairs of buses or matrices, odd side first: the desk keeps one tap point
    /// per pair (doc p.26), so a pair shares one › (mock B, 2026-10-12). A linked pair is one send, held by its odd
    /// side, as on the desk. Assumed: the desk copies the odd send's level to the even one while linked (m32-probe).
    public func sendPairs(of strip: StripID) -> [[StripID]] {
        guard let kind = strip.kind.sendTarget else { return [] }
        return StripID.all(kind).filter(\.isOddSide).map { odd in
            guard !isLinked(odd), let even = odd.partner else { return [odd] }
            return [odd, even]
        }
    }
}

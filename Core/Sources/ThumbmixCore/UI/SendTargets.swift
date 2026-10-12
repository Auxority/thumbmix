extension ConsoleMirror {
    /// The rows of `strip`'s Sends tab: a linked pair of buses or matrices is one send, held by its odd side, as on
    /// the desk. Assumed: the desk copies the odd send's level to the even one while linked (m32-probe).
    public func sendTargets(of strip: StripID) -> [StripID] {
        guard let kind = strip.kind.sendTarget else { return [] }
        return StripID.all(kind).filter { $0 == $0.oddSide || !isLinked($0) }
    }
}

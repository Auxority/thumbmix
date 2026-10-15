extension ConsoleMirror {
    /// What a label calls a strip: a linked pair by its one shared name, any other strip by its own.
    public func displayName(_ strip: StripID) -> String {
        isLinked(strip) ? pairName(strip) : name(strip)
    }
}

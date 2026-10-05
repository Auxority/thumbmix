#if DEBUG
public extension ConsoleMirror {
    /// A live-looking mirror filled with the demo band and no network, for SwiftUI previews.
    static func preview(_ state: [String: OSCArgument] = DemoState.values()) -> ConsoleMirror {
        let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9), auditAddresses: [])
        for (address, value) in state { mirror.apply(OSCMessage(address, [value])) }
        mirror.status = .live
        return mirror
    }
}
#endif

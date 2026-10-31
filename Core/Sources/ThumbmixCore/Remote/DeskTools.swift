import Foundation

/// The tools the remote API offers, on the app's own `ConsoleMirror`: reads show only what the desk sent, writes go
/// through `ConsoleMirror.set` (no write while contact is lost, none over a value never read) after the tool has read
/// what it needs and checked every value, so a refused request changes nothing.
@MainActor
final class DeskTools {
    var mirror: ConsoleMirror
    let readTimeout: Duration

    init(mirror: ConsoleMirror, readTimeout: Duration) {
        self.mirror = mirror
        self.readTimeout = readTimeout
    }

    var table: ToolTable { ToolTable(tools: [listStrips, getStrip, setFader, setMute, setEQBand, setComp]) }

    // MARK: Access

    /// Reads and writes both start here: the names and values are only the desk's once the sync is done.
    func requireLive() throws {
        switch mirror.status {
        case .live:
            return
        case .lost:
            throw ToolError.unavailable(
                "Contact with the console is lost, so nothing was read or written. Thumbmix reconnects by itself; "
                    + "try again in a few seconds.")
        case .failed:
            throw ToolError.unavailable("Thumbmix cannot reach an M32 on the network, so nothing was read or written.")
        case .connecting, .syncing:
            throw ToolError.unavailable("Thumbmix is still connecting to the console; try again in a few seconds.")
        }
    }

    func resolve(_ query: String) throws -> StripID {
        let entries = StripKind.allCases.flatMap(StripID.all).map { strip in
            StripLookup.Entry(strip: strip, names: [mirror.rawName(strip), strip.defaultName].filter { !$0.isEmpty })
        }
        switch StripLookup(entries: entries).match(query) {
        case .found(let strip):
            return strip
        case .ambiguous(let candidates):
            let shown = candidates.prefix(8).map(describe).joined(separator: ", ")
            let more = candidates.count > 8 ? " and \(candidates.count - 8) more" : ""
            throw ToolError.invalid(
                "'\(query)' fits \(candidates.count) strips: \(shown)\(more). Use an id, or a longer name.")
        case .unknown:
            throw ToolError.invalid("No strip is called '\(query)'. Call list_strips to see the ids and names.")
        }
    }

    /// "Tom 1 (ch/04)".
    func describe(_ strip: StripID) -> String { "\(mirror.name(strip)) (\(StripLookup.id(of: strip)))" }

    /// Reads `tabs` of `strip` as the app does when a tab opens, and waits until every address in `needed` has
    /// answered or been given up on (the mirror asks again for lost replies first). A value that never comes stays
    /// unread: the tools report it unknown and refuse to write over it.
    func read(_ tabs: [ChannelTab], of strip: StripID, needing needed: [String]) async throws {
        for tab in tabs where ChannelTab.tabs(for: strip.kind).contains(tab) { mirror.read(tab, of: strip) }
        let deadline = ContinuousClock.now + readTimeout
        while ContinuousClock.now < deadline {
            try requireLive()
            if needed.allSatisfy({ mirror.cell($0).argument != nil || mirror.reads.missing.contains($0) }) { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Waits (briefly) until the mirror has put these writes on the wire: its send loop runs every 20 ms.
    func waitUntilSent(_ addresses: [String]) async {
        let deadline = ContinuousClock.now + .seconds(1)
        while ContinuousClock.now < deadline, addresses.contains(where: { mirror.pendingSends[$0] != nil }) {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

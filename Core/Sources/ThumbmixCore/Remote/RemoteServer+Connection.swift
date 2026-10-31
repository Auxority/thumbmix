import Foundation
import os

/// The number that groups one request's log lines, whichever front end it came by.
enum RequestIDs {
    private static let counter = OSAllocatedUnfairLock(initialState: 0)

    static func next() -> Int {
        counter.withLock { count -> Int in
            count += 1
            return count
        }
    }
}

extension RemoteServer {
    /// When the first identify gets no reply (the desk is off, or the address is wrong) the link gives up and its mirror
    /// stops, as the app's Connect screen shows. Here nobody is there to tap Connect again, so each `retryEvery` a failed
    /// mirror is replaced by `makeMirror`'s and started. Once the desk has answered, the link itself rides out outages
    /// and resyncs; tools meanwhile answer "lost" or "still connecting". Runs until cancelled.
    public func keepConnected(retryEvery: Duration, makeMirror: @MainActor () -> ConsoleMirror) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: retryEvery)
            guard let failure = tools.mirror.failure else { continue }
            log.warning("no console yet (\(String(describing: failure), privacy: .public)); trying again")
            tools.mirror.stop()
            let next = makeMirror()
            next.start()
            tools.mirror = next
        }
    }
}

import Foundation
import Observation
import ThumbmixCore

@MainActor @Observable
final class AppModel {
    private(set) var mirror: ConsoleMirror?
    private(set) var host: String?
    private static let lastHostKey = "lastConsoleHost"

    var failure: LinkFailure? {
        guard case let .failed(failure)? = mirror?.status else { return nil }
        return failure
    }

    var lastHost: String? { UserDefaults.standard.string(forKey: Self.lastHostKey) }

    func connect(to host: String) {
        guard Discovery.isValidIPv4(host) else { return }
        mirror?.stop()
        let mirror = ConsoleMirror(link: ConsoleLink(host: host))
        mirror.start()
        self.mirror = mirror
        self.host = host
        UserDefaults.standard.set(host, forKey: Self.lastHostKey)
    }

    func connectToLastConsole() {
        guard mirror == nil, let lastHost else { return }
        connect(to: lastHost)
    }

    func disconnect() {
        mirror?.stop()
        mirror = nil
    }
}

import FakeM32
import Foundation
import Observation
import ThumbmixCore

@MainActor @Observable
final class AppModel {
    private(set) var mirror: ConsoleMirror?
    private(set) var host: String?
    /// The demo console Offline mode runs inside the app; nil when connected to a real desk.
    private var demoConsole: FakeM32?
    private(set) var offlineFailed = false
    private static let lastHostKey = "lastConsoleHost"

    var isOffline: Bool { demoConsole != nil }

    var failure: LinkFailure? {
        guard case .failed(let failure)? = mirror?.status else { return nil }
        return failure
    }

    var lastHost: String? { UserDefaults.standard.string(forKey: Self.lastHostKey) }

    func connect(to host: String) {
        guard Discovery.isUsableIPv4(host) else { return }
        disconnect()
        let mirror = ConsoleMirror(link: ConsoleLink(host: host))
        mirror.start()
        self.mirror = mirror
        self.host = host
        UserDefaults.standard.set(host, forKey: Self.lastHostKey)
    }

    /// Every visit gets a fresh demo desk. It never becomes the last console, so a relaunch can't land on it.
    func startOffline() async {
        disconnect()
        do {
            let demo = try FakeM32()
            let port = try await demo.start()
            let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: port))
            mirror.start()
            demoConsole = demo
            self.mirror = mirror
            offlineFailed = false
        } catch {
            offlineFailed = true
        }
    }

    func connectToLastConsole() {
        guard mirror == nil, let lastHost else { return }
        connect(to: lastHost)
    }

    /// Coming back from the background: anything could have changed on the desk meanwhile.
    func wake() {
        mirror?.wake()
    }

    func disconnect() {
        mirror?.stop()
        mirror = nil
        host = nil
        demoConsole?.stop()
        demoConsole = nil
    }
}

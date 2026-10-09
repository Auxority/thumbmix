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
    private(set) var isStartingOffline = false
    private static let lastHostKey = "lastConsoleHost"

    var isOffline: Bool { demoConsole != nil }

    var failure: LinkFailure? {
        guard case .failed(let failure)? = mirror?.status else { return nil }
        return failure
    }

    var lastHost: String? { UserDefaults.standard.string(forKey: Self.lastHostKey) }

    /// A real M32 always listens on 10023. UI tests pass `-consolePort` to reach the fake desk each test starts.
    private static var consolePort: UInt16 {
        #if DEBUG
            let port = UserDefaults.standard.integer(forKey: "consolePort")
            if (1...65535).contains(port) { return UInt16(port) }
        #endif
        return 10023
    }

    func connect(to host: String) {
        guard Discovery.isUsableIPv4(host) else { return }
        disconnect()
        let mirror = ConsoleMirror(link: ConsoleLink(host: host, port: Self.consolePort))
        mirror.start()
        self.mirror = mirror
        self.host = host
        UserDefaults.standard.set(host, forKey: Self.lastHostKey)
    }

    /// Every visit gets a fresh demo desk. It never becomes the last console, so a relaunch can't land on it.
    /// A second tap while the first demo desk starts would replace it without stopping it.
    func startOffline() async {
        guard !isStartingOffline else { return }
        isStartingOffline = true
        defer { isStartingOffline = false }
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

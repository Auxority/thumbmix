import FakeM32
import Foundation
import Observation
import ThumbmixCore

@MainActor @Observable
final class AppModel {
    private(set) var mirror: ConsoleMirror?
    /// What the failure alert calls the console being connected to: its name when known, else its address.
    private(set) var target: String?
    /// The demo console Offline mode runs inside the app; nil when connected to a real desk.
    private var demoConsole: FakeM32?
    private(set) var offlineFailed = false
    private(set) var isStartingOffline = false
    private(set) var known = KnownConsoles(stored: UserDefaults.standard.array(forKey: AppModel.knownKey))
    private static let knownKey = "knownConsoles"
    /// Desks ("host:port") whose Exclusive solo the engineer chose to keep. In memory only: the next launch asks again,
    /// as the next show may want the hunt (2026-10-19).
    private var keptExclusiveSolo: Set<String> = []
    private var deskKey: String?

    var isOffline: Bool { demoConsole != nil }

    var failure: LinkFailure? { mirror?.failure }

    /// A real M32 always listens on 10023. UI tests pass `-consolePort` to reach the fake desk each test starts.
    static var consolePort: UInt16 {
        #if DEBUG
            let port = UserDefaults.standard.integer(forKey: "consolePort")
            if (1...65535).contains(port) { return UInt16(port) }
        #endif
        return 10023
    }

    /// A console that answers as an M32 is remembered under the name set on the desk; the demo never is.
    func connect(to host: String, name: String? = nil, port: UInt16 = AppModel.consolePort) {
        guard Discovery.isUsableIPv4(host) else { return }
        disconnect()
        let mirror = ConsoleMirror(link: ConsoleLink(host: host, port: port))
        mirror.onIdentified = { [weak self] info in
            self?.remember(NetworkConsole(host: host, name: info.name, model: info.model))
        }
        let key = "\(host):\(port)"
        mirror.keepsExclusiveSolo = keptExclusiveSolo.contains(key)
        mirror.start()
        self.mirror = mirror
        deskKey = key
        target = name ?? host
    }

    /// The engineer answered Keep to the Exclusive solo question: not asked again for this desk until the app quits.
    func keepExclusiveSolo() {
        if let deskKey { keptExclusiveSolo.insert(deskKey) }
    }

    func forget(_ console: NetworkConsole) {
        known.forget(console)
        UserDefaults.standard.set(known.stored, forKey: Self.knownKey)
    }

    private func remember(_ console: NetworkConsole) {
        known.remember(console)
        UserDefaults.standard.set(known.stored, forKey: Self.knownKey)
    }

    /// Every visit gets a fresh demo desk. A second tap while the first demo desk starts would replace it without
    /// stopping it.
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

    func dismissOfflineFailure() {
        offlineFailed = false
    }

    #if DEBUG
        /// The app opens on the Connect screen; UI tests that need a desk at once pass `-connectOnLaunch YES`.
        func connectOnLaunch() {
            guard mirror == nil, UserDefaults.standard.bool(forKey: "connectOnLaunch") else { return }
            connect(to: "127.0.0.1")
        }

        /// UI tests launch the app once per test class (a launch is most of a test's time) and send each next
        /// test's fresh fake desk as `thumbmix-test://connect?port=N`. Always this Mac's loopback, never another host.
        /// XCUITest can't shake a simulator, so `thumbmix-test://shake` plays one.
        func openTestURL(_ url: URL) {
            guard url.scheme == "thumbmix-test" else { return }
            if url.host() == "shake" { NotificationCenter.default.post(name: .deviceShaken, object: nil) }
            guard url.host() == "connect",
                let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                    .first(where: { $0.name == "port" })?.value,
                let port = UInt16(value), port > 0
            else { return }
            connect(to: "127.0.0.1", port: port)
        }
    #endif

    /// Coming back from the background: anything could have changed on the desk meanwhile.
    func wake() {
        mirror?.wake()
    }

    func disconnect() {
        mirror?.stop()
        mirror = nil
        target = nil
        deskKey = nil
        demoConsole?.stop()
        demoConsole = nil
    }
}

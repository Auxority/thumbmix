import SwiftUI
import ThumbmixCore
import UIKit

extension Notification.Name {
    static let deviceShaken = Notification.Name("thumbmix.deviceShaken")
}

/// iOS reports a shake to the key window, which SwiftUI doesn't pass on.
extension UIWindow {
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { NotificationCenter.default.post(name: .deviceShaken, object: nil) }
        super.motionEnded(motion, with: event)
    }
}

/// A shake on any screen offers this run's log as a file for a GitHub issue (2026-10-26): no button anywhere, and the
/// desk stays connected.
struct ShakeToShareLog: ViewModifier {
    @State private var isAsking = false
    @State private var reading: Task<SharedLog, Never>?
    @State private var shared: SharedLog?

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceShaken)) { _ in
                // Reading the log takes seconds on a phone: it starts now, while the question is read.
                reading = Task.detached { SharedLog.write() }
                isAsking = true
            }
            .alert("Share this run's log?", isPresented: $isAsking) {
                Button("Cancel", role: .cancel) {}
                Button("Share") { Task { shared = await reading?.value } }
            } message: {
                Text("To attach to a GitHub issue about a problem you just saw.")
            }
            .sheet(item: $shared) { ShareSheet(url: $0.url) }
    }
}

struct SharedLog: Identifiable, Sendable {
    let url: URL
    var id: URL { url }

    static func write() -> SharedLog {
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] ?? "?") (\(info?["CFBundleVersion"] ?? "?"))"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let header = "Thumbmix \(version), \(machine()), iOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        let text: String
        do {
            text = try LogFile.text(header: header)
        } catch {
            text = "\(header)\n\nCouldn't read this run's log: \(error)\n"
        }
        let stamp = Date.now.formatted(.iso8601).replacingOccurrences(of: ":", with: ".")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Thumbmix log \(stamp).txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return SharedLog(url: url)
    }

    /// "iPhone12,3" names the model; `UIDevice.model` only says "iPhone".
    private static func machine() -> String {
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

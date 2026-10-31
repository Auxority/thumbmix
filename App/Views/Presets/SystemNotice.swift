import OSLog
import SwiftUI

/// A notice for something that happens outside the screen the engineer is on (a file opened from AirDrop). A SwiftUI
/// alert on the root view dismissed the edit sheet to show itself, and with it a name, colour or icon picked but not yet
/// sent, so this one is presented over whatever is on top. A safety question is never covered: it waits for the alert
/// on top to be answered.
@MainActor
enum SystemNotice {
    private static let log = Logger(subsystem: "thumbmix", category: "notice")
    private static let waits = 120
    private static let wait = Duration.milliseconds(500)

    static func show(_ message: String) async {
        for _ in 0..<waits {
            if let top = topViewController(), !(top is UIAlertController) {
                let alert = UIAlertController(title: String(localized: "Presets"), message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
                top.present(alert, animated: true)
                return
            }
            try? await Task.sleep(for: wait)
        }
        log.error("notice never shown: another alert stayed open for a minute")
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.keyWindow?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }
}

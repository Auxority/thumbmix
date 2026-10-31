import OSLog
import SwiftUI

/// A notice for something that arrives from outside the screen the engineer is on (a file opened from AirDrop). A
/// SwiftUI alert on the root view dismissed the edit sheet to show itself, and with it a name, colour or icon picked
/// but not yet sent, so this one is presented over whatever is on top. A safety question is never covered: it waits
/// for the alert on top to be answered, and for a closing sheet to be gone. Notices a screen raises itself stay with
/// `noticeAlert`.
@MainActor
enum SystemNotice {
    private static let log = Logger(subsystem: "thumbmix", category: "notice")
    private static let poll = Duration.milliseconds(500)
    private static let longWait = 120

    /// Waits as long as it takes: whatever the notice reports has already happened, so it must be shown.
    static func show(_ message: String, title: String) async {
        var polls = 0
        while true {
            if let top = topViewController(), !(top is UIAlertController), !top.isBeingDismissed {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
                top.present(alert, animated: true)
                return
            }
            polls += 1
            if polls == longWait { log.error("a notice has waited a minute for another alert to close") }
            try? await Task.sleep(for: poll)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.keyWindow?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }
}

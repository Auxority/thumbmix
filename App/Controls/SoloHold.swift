import OSLog
import SwiftUI

/// A finger resting on an overview name, then moving (2026-10-19). UIKit's long press, as Photos uses: a quick flick
/// moves more than `allowableMovement` before the hold and scrolls instead, and a recognised hold cancels the name's
/// tap. Points come in `space`, so the overview maps them to rows.
struct SoloHold: UIGestureRecognizerRepresentable {
    enum Phase { case began, moved, ended }

    let space: NamedCoordinateSpace
    let onChange: (Phase, CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let hold = UILongPressGestureRecognizer()
        // Longer than a sloppy tap, which must still open the strip; shorter than the fader's hold (0.5 s).
        hold.minimumPressDuration = 0.3
        hold.allowableMovement = 10
        return hold
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        Logger(subsystem: "thumbmix", category: "solo").debug("hold state \(recognizer.state.rawValue)")
        let point = context.converter.location(in: space)
        switch recognizer.state {
        case .began: onChange(.began, point)
        case .changed: onChange(.moved, point)
        case .ended, .cancelled, .failed: onChange(.ended, point)
        default: break
        }
    }
}

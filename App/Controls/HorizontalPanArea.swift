import SwiftUI
import UIKit

/// A transparent touch area that claims only mostly-horizontal drags, so vertical swipes still
/// scroll the list. SwiftUI's DragGesture can't decline a drag once it starts; UIKit's delegate can.
struct HorizontalPanArea: UIViewRepresentable {
    var onBegan: () -> Void
    /// Each movement since the last, and how far the finger is above or below the area (0 on it).
    var onMoved: (_ distance: CGFloat, _ width: CGFloat, _ outside: CGFloat) -> Void
    var onEnded: () -> Void
    var onDoubleTap: () -> Void
    var onHold: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.doubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        // A still hold; any real movement makes it a drag or a scroll instead.
        let hold = UILongPressGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.hold(_:)))
        hold.minimumPressDuration = 0.5
        hold.allowableMovement = 10
        view.addGestureRecognizer(hold)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: HorizontalPanArea
        private var lastX: CGFloat = 0

        init(parent: HorizontalPanArea) { self.parent = parent }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .began:
                lastX = 0
                parent.onBegan()
            case .changed:
                let x = recognizer.translation(in: view).x
                let y = recognizer.location(in: view).y
                let outside = y < 0 ? -y : Swift.max(0, y - view.bounds.height)
                parent.onMoved(x - lastX, view.bounds.width, outside)
                lastX = x
            case .ended, .cancelled, .failed: parent.onEnded()
            default: break
            }
        }

        @objc func doubleTap() { parent.onDoubleTap() }

        @objc func hold(_ recognizer: UILongPressGestureRecognizer) {
            if recognizer.state == .began { parent.onHold() }
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

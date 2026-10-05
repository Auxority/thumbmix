import SwiftUI
import UIKit

/// A transparent touch area that claims only mostly-horizontal drags, so vertical swipes still
/// scroll the list. SwiftUI's DragGesture can't decline a drag once it starts; UIKit's delegate can.
struct HorizontalPanArea: UIViewRepresentable {
    var onBegan: () -> Void
    var onChanged: (_ translation: CGFloat, _ width: CGFloat) -> Void
    var onEnded: () -> Void
    var onDoubleTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: HorizontalPanArea

        init(parent: HorizontalPanArea) { self.parent = parent }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .began: parent.onBegan()
            case .changed: parent.onChanged(recognizer.translation(in: view).x, view.bounds.width)
            case .ended, .cancelled, .failed: parent.onEnded()
            default: break
            }
        }

        @objc func doubleTap() { parent.onDoubleTap() }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

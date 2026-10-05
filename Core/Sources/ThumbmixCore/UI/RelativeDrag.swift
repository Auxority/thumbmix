/// Relative dragging: the value moves from where it was, never jumps to the finger.
public enum RelativeDrag {
    /// Full control width = full range, so the feel follows the desk's own fader taper.
    public static func value(start: Float, translation: Double, width: Double, scale: ParamScale) -> Float {
        guard width > 0 else { return start }
        return scale.snap(start + Float(translation / width))
    }

    public static func crossed(_ mark: Float, from old: Float, to new: Float) -> Bool {
        (old < mark && new >= mark) || (old > mark && new <= mark)
    }

    /// One VoiceOver swipe: 1 dB on levels, one option on choices, about 1 % of the range elsewhere
    /// (never less than one console step, or the swipe would do nothing).
    public static func stepped(_ normalized: Float, by direction: Int, scale: ParamScale) -> Float {
        switch scale {
        case .fader, .sendLevel:
            return nudged(normalized, byDecibels: Double(direction), scale: scale)
        default:
            let step = Swift.max(1 / Float(scale.steps - 1), 0.01)
            return scale.snap(normalized + Float(direction) * step)
        }
    }

    public static func nudged(_ normalized: Float, byDecibels delta: Double, scale: ParamScale) -> Float {
        let current = scale.value(fromNormalized: normalized)
        return scale.normalized(forValue: (current.isFinite ? current : -90) + delta)
    }
}

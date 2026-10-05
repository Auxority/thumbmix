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

    public static func nudged(_ normalized: Float, byDecibels delta: Double, scale: ParamScale) -> Float {
        let current = scale.value(fromNormalized: normalized)
        return scale.normalized(forValue: (current.isFinite ? current : -90) + delta)
    }
}

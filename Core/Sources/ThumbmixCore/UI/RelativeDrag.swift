/// Relative dragging: the value moves from where it was, never jumps to the finger.
public enum RelativeDrag {
    /// Full control width = full range at full speed, so the feel follows the desk's own fader taper. Not snapped:
    /// the drag adds up its movements, and small slow ones would vanish if each were rounded to a desk step.
    public static func moved(_ position: Float, by distance: Double, width: Double, speed: Double) -> Float {
        guard width > 0 else { return position }
        return Swift.min(Swift.max(position + Float(distance / width * speed), 0), 1)
    }

    /// Like the iOS video scrubber: full speed on the row, half once the finger strays a row height above or below
    /// it, a quarter beyond three. Finer than the row's width allows, without a separate control.
    public static func speed(outside distance: Double, rowHeight: Double) -> Double {
        switch distance {
        case (rowHeight * 3)...: 0.25
        case rowHeight...: 0.5
        default: 1
        }
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

    /// Moves from the value as shown (to 0.1 dB, faders as the desk shows them): the grid's rounding (up to
    /// 0.02 dB above −10 dB) would otherwise add up tap after tap, drifting the display to x.1 and x.2.
    public static func nudged(_ normalized: Float, byDecibels delta: Double, scale: ParamScale)
        -> Float
    {
        let shown =
            scale == .fader
            ? FaderLaw.shownDecibels(fromWire: Double(normalized))
            : (scale.value(fromNormalized: normalized) * 10).rounded() / 10
        return scale.normalized(forValue: (shown.isFinite ? shown : -90) + delta)
    }
}

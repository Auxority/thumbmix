import Foundation

/// One value of a preset next to the desk control it sets on a given strip. Validation, loading and the preset's own
/// page all read a preset through these, so each rule exists once.
struct PresetField {
    /// The control's path under the strip ("gate/thr"): what a refusal names.
    let path: String
    /// nil where the strip has no such control. Validation refuses that; a load can't take the part.
    let spec: ParamSpec?
    let value: PresetValue

    /// The values a load asks about before it writes them.
    enum Role { case gain, trim, phantom, polarity, compPosition }

    var role: Role? {
        switch path {
        case "headamp/gain": .gain
        case "headamp/phantom": .phantom
        case "preamp/trim": .trim
        case "preamp/invert": .polarity
        case "dyn/pos": .compPosition
        default: nil
        }
    }

    /// `value` as the number the spec's scale speaks (a switch is 0 or 1, a choice its index); nil where the value's
    /// kind doesn't suit the control, or a choice isn't among its options.
    var real: Double? {
        switch (value, spec?.scale) {
        case (.flag(let flag), .toggle?): flag ? 1 : 0
        case (.option(let name), .choice(let options)?): options.firstIndex(of: name).map(Double.init)
        case (.number, .toggle?), (.number, .choice?), (_, nil): nil
        case (.number(let number), _): number
        default: nil
        }
    }
}

extension Preset {
    /// The values of `part` next to the controls of `strip`, in the order the part lists its controls; a path the strip
    /// lacks comes last. `headamp` is the preamp feeding the strip: without one, gain and 48V have no control.
    func fields(of part: PresetPart, on strip: StripID, headamp: Int?) -> [PresetField] {
        guard let values = values[part] else { return [] }
        let known = part.specs(on: strip, headamp: headamp).compactMap { spec -> PresetField? in
            let path = PresetPart.path(of: spec, on: strip)
            return values[path].map { PresetField(path: path, spec: spec, value: $0) }
        }
        let paths = Set(known.map(\.path))
        let unknown = values.filter { !paths.contains($0.key) }.sorted { $0.key < $1.key }
        return known + unknown.map { PresetField(path: $0.key, spec: nil, value: $0.value) }
    }
}

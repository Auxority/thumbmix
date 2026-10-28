import Foundation

/// Whether one part of a preset can be loaded onto a strip now; the load sheet greys what it can't, with the reason.
public enum PartFit: Equatable, Sendable {
    case fits
    case notInPreset
    /// The strip's values aren't all read yet: `set` skips an unread control, so a load would write only part.
    case reading
    case cannot(String)
}

public struct PresetWrite: Equatable, Sendable {
    public let address: String
    public let argument: OSCArgument
}

/// What `apply` did: a load that was not sent, or held a write back, says so rather than looking done.
public enum LoadOutcome: Equatable, Sendable {
    case sent
    case notLive
    /// Writes left out because the desk moved during the alerts, so they now need a question nobody was asked.
    case heldBack(Int)
}

/// What loading a preset would write. `questions` hold the writes that need the engineer's yes first: raising the gain
/// or trim, switching 48V, flipping polarity, moving the comp past mixes that hear it. Whatever the source.
public struct LoadPlan: Equatable, Sendable {
    /// What the plan was made from: `apply` plans again from these against the desk as it is then.
    let preset: Preset
    let parts: Set<PresetPart>
    let strip: StripID
    public var writes: [PresetWrite] = []
    public var questions: [PresetQuestion] = []
}

extension ConsoleMirror {
    public func fit(of part: PresetPart, in preset: Preset, onto strip: StripID) -> PartFit {
        guard preset.holds(part) else { return .notInPreset }
        if let reason = reasonItCannot(part, preset, onto: strip) { return .cannot(reason) }
        return isReadToLoad(part, preset, onto: strip) ? .fits : .reading
    }

    /// The writes for the ticked parts that fit, and the questions to ask first. Nothing is sent.
    public func loadPlan(
        _ preset: Preset, parts: Set<PresetPart>, onto strip: StripID, locale: Locale = .current
    ) -> LoadPlan {
        var plan = LoadPlan(preset: preset, parts: parts, strip: strip)
        for part in PresetPart.allCases where parts.contains(part) && fit(of: part, in: preset, onto: strip) == .fits {
            for field in preset.fields(of: part, on: strip, headamp: headamp(of: strip)) {
                guard let spec = field.spec, let real = field.real else { continue }
                let write = PresetWrite(address: spec.address, argument: Catalog.deskArguments([(spec, real)])[0].argument)
                switch judge(field, spec, write, strip: strip, locale: locale) {
                case .plain: plan.writes.append(write)
                case .unchanged: continue
                case .ask(let question): plan.questions.append(question)
                }
            }
        }
        return plan
    }

    /// Plans again against the desk as it is now, so `judge` alone decides what asks, also after the desk moved during
    /// the alerts. Sends the writes that need no answer and those answered yes; an address answered "Keep" is never
    /// written, and a question nobody was asked holds its write back.
    @discardableResult
    public func apply(_ plan: LoadPlan, answers: [String: Bool]) -> LoadOutcome {
        guard isLive else { return .notLive }
        let now = loadPlan(plan.preset, parts: plan.parts, onto: plan.strip)
        for write in now.writes where answers[write.address] != false { set(write.address, write.argument) }
        for question in now.questions where answers[question.id] == true {
            set(question.write.address, question.write.argument)
        }
        let heldBack = now.questions.filter { answers[$0.id] == nil }.count
        return heldBack == 0 ? .sent : .heldBack(heldBack)
    }

    private func partnerSpec(_ role: PresetField.Role?, _ strip: StripID) -> ParamSpec? {
        guard let partner = gainDelayPartner(of: strip) else { return nil }
        switch role {
        case .gain: return headamp(of: partner).map(Catalog.headampGain)
        case .trim: return Catalog.trim(partner)
        default: return nil
        }
    }

    // MARK: Fit

    private func reasonItCannot(_ part: PresetPart, _ preset: Preset, onto strip: StripID) -> String? {
        guard part.exists(on: strip) else { return Self.missingText(part) }
        let bands = StripID(preset.stripKind, 1).eqBandCount
        switch part {
        case .eq where bands != strip.eqBandCount:
            return CoreStrings.text("This EQ has \(bands) bands; this strip has \(strip.eqBandCount).")
        case .sends where preset.stripKind.sendTarget != strip.kind.sendTarget:
            return CoreStrings.text("This strip's sends go to other mixes.")
        default:
            return lacksSetting(part, preset, onto: strip) ? CoreStrings.text("This strip lacks a setting the preset uses.") : nil
        }
    }

    private static func missingText(_ part: PresetPart) -> String {
        switch part {
        case .input: CoreStrings.text("This strip has no Input tab.")
        case .eq: CoreStrings.text("This strip has no EQ.")
        case .gate: CoreStrings.text("Only inputs have a gate.")
        case .comp: CoreStrings.text("This strip has no compressor.")
        case .mix, .sends: CoreStrings.text("This strip has no sends.")
        }
    }

    /// A value with no control here, or one its control can't take: a filter type only mains and matrices have. Gain
    /// and 48V are the exception: a strip no preamp feeds loads the rest of Input without them.
    private func lacksSetting(_ part: PresetPart, _ preset: Preset, onto strip: StripID) -> Bool {
        preset.fields(of: part, on: strip, headamp: headamp(of: strip)).contains { field in
            field.real == nil && !(field.spec == nil && [.gain, .phantom].contains(field.role))
        }
    }

    private func isReadToLoad(_ part: PresetPart, _ preset: Preset, onto strip: StripID) -> Bool {
        let specs = preset.fields(of: part, on: strip, headamp: headamp(of: strip)).compactMap(\.spec)
        guard specs.allSatisfy({ cell($0.address).argument != nil }) else { return false }
        // The comp's question needs every send's switch and tap, which the Comp tab reads.
        return part != .comp || mixesChangedByMovingComp(of: strip) != nil
    }

    // MARK: Questions

    private enum Judgement {
        case plain
        case unchanged
        case ask(PresetQuestion)
    }

    private func judge(_ field: PresetField, _ spec: ParamSpec, _ write: PresetWrite, strip: StripID, locale: Locale)
        -> Judgement
    {
        guard let role = field.role, let current = value(spec), let new = field.real else { return .plain }
        // The desk holds the value on its own grid: that is what the engineer would end up with.
        let snapped = spec.scale.value(fromNormalized: spec.scale.normalized(forValue: new))
        // The desk copies a gain or trim to a linked partner, so the lower of the two sides is what would rise most.
        let sides = [current] + (partnerSpec(role, strip).flatMap { value($0) }.map { [$0] } ?? [])
        guard sides.contains(where: { $0 != snapped }) else { return .unchanged }
        let from = role == .gain || role == .trim ? sides.min() ?? current : current
        let change = PresetChange(role: role, from: from, to: snapped, write: write)
        let who = PresetWho(self, strip, locale: locale)
        let mixes = role == .compPosition ? mixesChangedByMovingComp(of: strip) ?? [] : []
        return change.question(who, mixes: mixes).map { .ask($0) } ?? .plain
    }
}

/// A value the load would change on a control that asks first.
struct PresetChange {
    let role: PresetField.Role
    let from: Double
    let to: Double
    let write: PresetWrite

    /// nil where the change needs no question: a lower gain or trim, a comp move no mix hears.
    func question(_ who: PresetWho, mixes: [String]) -> PresetQuestion? {
        switch role {
        case .gain, .trim: to > from ? .raise(isGain: role == .gain, who: who, from: from, to: to, write: write) : nil
        case .phantom: .phantom(on: to == 1, who: who, write: write)
        case .polarity: .polarity(isFlipped: from == 1, who: who, write: write)
        case .compPosition: mixes.isEmpty ? nil : .compMove(movesBeforeEQ: to == 0, mixes: mixes, write: write)
        }
    }
}

/// Whom a load question names: the pair when the desk shares gain and delay between a linked pair's sides, so the
/// alert's title says what the answer reaches; else the strip.
struct PresetWho {
    let name: String
    /// Other strips on the same preamp, besides a linked partner the name already covers.
    let sameInput: String?
    let locale: Locale

    @MainActor init(_ mirror: ConsoleMirror, _ strip: StripID, locale: Locale) {
        let partner = mirror.gainDelayPartner(of: strip)
        name = partner == nil ? mirror.name(strip) : mirror.pairName(strip)
        sameInput = mirror.namesSharingHeadamp(with: strip, besides: partner, locale: locale)
        self.locale = locale
    }
}

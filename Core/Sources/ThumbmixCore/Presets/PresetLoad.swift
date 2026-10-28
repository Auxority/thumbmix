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
    /// The level this write sets, and the controls (a linked partner's too) whose level it must not raise unasked:
    /// checked again when the write is sent, since the desk may have moved during the alerts.
    let target: Double
    let raisingGuards: [ParamSpec]
}

/// What `apply` did: a load that was not sent, or held a write back, says so rather than looking done.
public enum LoadOutcome: Equatable, Sendable {
    case sent
    case notLive
    /// Writes left out because the gain or trim they set had meanwhile been lowered on the desk.
    case heldBack(Int)
}

/// What loading a preset would write. `questions` hold the writes that need the engineer's yes first: raising the gain
/// or trim, switching 48V, flipping polarity, moving the comp past mixes that hear it. Whatever the source.
public struct LoadPlan: Equatable, Sendable {
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
        var plan = LoadPlan()
        for part in PresetPart.allCases where parts.contains(part) && fit(of: part, in: preset, onto: strip) == .fits {
            for field in preset.fields(of: part, on: strip, headamp: headamp(of: strip)) {
                guard let spec = field.spec, let real = field.real else { continue }
                let guards = raisingGuards(field, spec, strip)
                let write = PresetWrite(
                    address: spec.address, argument: Catalog.deskArguments([(spec, real)])[0].argument,
                    target: spec.scale.value(fromNormalized: spec.scale.normalized(forValue: real)),
                    raisingGuards: guards)
                switch judge(field, spec, write, preset: preset, strip: strip, locale: locale) {
                case .plain: plan.writes.append(write)
                case .unchanged: continue
                case .ask(let make): plan.questions.append(make(plan.questions.count))
                }
            }
        }
        return plan
    }

    /// Sends the writes that need no answer, and those of each question the engineer confirmed. A question left out
    /// is a "Keep": its writes are dropped and the rest loads.
    @discardableResult
    public func apply(_ plan: LoadPlan, accepting accepted: Set<Int>) -> LoadOutcome {
        guard isLive else { return .notLive }
        var heldBack = 0
        for write in plan.writes {
            if wouldRaise(write) { heldBack += 1 } else { set(write.address, write.argument) }
        }
        for question in plan.questions where accepted.contains(question.id) {
            for write in question.writes { set(write.address, write.argument) }
        }
        return heldBack == 0 ? .sent : .heldBack(heldBack)
    }

    /// A write judged "lower, no question" that the desk's own level has meanwhile fallen under.
    private func wouldRaise(_ write: PresetWrite) -> Bool {
        write.raisingGuards.contains { value($0).map { $0 < write.target } ?? false }
    }

    /// The gain or trim, and the same control on a linked partner, which the desk copies the write to.
    private func raisingGuards(_ field: PresetField, _ spec: ParamSpec, _ strip: StripID) -> [ParamSpec] {
        guard field.role == .gain || field.role == .trim else { return [] }
        return [spec] + (partnerSpec(field.role, strip).map { [$0] } ?? [])
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
        guard part.exists(on: strip) else {
            switch part {
            case .input: return CoreStrings.text("This strip has no Input tab.")
            case .eq: return CoreStrings.text("This strip has no EQ.")
            case .gate: return CoreStrings.text("Only inputs have a gate.")
            case .comp: return CoreStrings.text("This strip has no compressor.")
            case .mix, .sends: return CoreStrings.text("This strip has no sends.")
            }
        }
        switch part {
        case .eq: return reasonEQCannot(preset, onto: strip)
        case .sends:
            return preset.stripKind.sendTarget == strip.kind.sendTarget
                ? nil : CoreStrings.text("This strip's sends go to other mixes.")
        default: return nil
        }
    }

    /// The same band count and every filter type among the strip's own: mains and matrices have 14, the rest 6.
    private func reasonEQCannot(_ preset: Preset, onto strip: StripID) -> String? {
        guard let eq = preset.eq else { return nil }
        guard eq.bands.count == strip.eqBandCount else {
            return CoreStrings.text("This EQ has \(eq.bands.count) bands; this strip has \(strip.eqBandCount).")
        }
        guard case .choice(let types) = Catalog.eqBand(strip, 1).type.scale,
            eq.bands.allSatisfy({ types.contains($0.type) })
        else { return CoreStrings.text("This strip's EQ lacks a filter type the preset uses.") }
        return nil
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
        case ask((Int) -> PresetQuestion)
    }

    private func judge(
        _ field: PresetField, _ spec: ParamSpec, _ write: PresetWrite, preset: Preset, strip: StripID, locale: Locale
    ) -> Judgement {
        guard let role = field.role, let current = value(spec), let new = field.real else { return .plain }
        // The desk holds the value on its own grid: that is what the engineer would end up with.
        let snapped = spec.scale.value(fromNormalized: spec.scale.normalized(forValue: new))
        // The desk copies a gain or trim to a linked partner, so the lower of the two sides is what would rise most.
        let sides = [current] + (partnerSpec(role, strip).flatMap { value($0) }.map { [$0] } ?? [])
        guard sides.contains(where: { $0 != snapped }) else { return .unchanged }
        let from = role == .gain || role == .trim ? sides.min() ?? current : current
        let change = PresetChange(role: role, from: from, to: snapped, writes: [write])
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
    let writes: [PresetWrite]

    /// nil where the change needs no question: a lower gain or trim, a comp move no mix hears.
    func question(_ who: PresetWho, mixes: [String]) -> ((Int) -> PresetQuestion)? {
        switch role {
        case .gain, .trim: return to > from ? { raise($0, who) } : nil
        case .phantom: return { PresetQuestion.phantom(id: $0, on: to == 1, who: who, writes: writes) }
        case .polarity: return { PresetQuestion.polarity(id: $0, isFlipped: from == 1, who: who, writes: writes) }
        case .compPosition: return mixes.isEmpty ? nil : { compMove($0, mixes) }
        }
    }

    private func raise(_ id: Int, _ who: PresetWho) -> PresetQuestion {
        PresetQuestion.raise(id: id, isGain: role == .gain, who: who, from: from, to: to, writes: writes)
    }

    private func compMove(_ id: Int, _ mixes: [String]) -> PresetQuestion {
        PresetQuestion.compMove(id: id, movesBeforeEQ: to == 0, mixes: mixes, writes: writes)
    }
}

/// Whom a load question names: the pair when the desk shares gain and delay between a linked pair's sides, so the
/// alert's title says what the answer reaches; else the strip.
struct PresetWho {
    let name: String
    let partnerName: String?
    /// Other strips on the same preamp, besides a linked partner the name already covers.
    let sameInput: String?
    let locale: Locale

    @MainActor init(_ mirror: ConsoleMirror, _ strip: StripID, locale: Locale) {
        let partner = mirror.gainDelayPartner(of: strip)
        name = partner == nil ? mirror.name(strip) : mirror.pairName(strip)
        partnerName = partner.map { mirror.name($0) }
        sameInput = mirror.namesSharingHeadamp(with: strip, besides: partner, locale: locale)
        self.locale = locale
    }
}

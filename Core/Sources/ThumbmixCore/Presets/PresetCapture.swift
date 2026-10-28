import Foundation

extension PresetPart {
    /// Whether the strip has this part at all: an aux in has no gate, a bus no Input tab, a matrix no sends.
    public func exists(on strip: StripID) -> Bool {
        guard strip.kind != .dca else { return false }
        switch self {
        case .input: return ChannelTab.tabs(for: strip.kind).contains(.input)
        case .eq: return strip.eqBandCount > 0
        case .gate: return strip.hasGate
        case .comp: return strip.hasDynamics
        case .mix: return true
        case .sends: return strip.kind.sendTarget != nil
        }
    }
}

extension ChannelTab {
    /// The tabs whose values a preset saves or loads: all but the lists of who feeds the strip.
    public static func presetTabs(for kind: StripKind) -> [ChannelTab] {
        tabs(for: kind).filter { $0 != .fedBy && $0 != .members }
    }
}

/// An unread value: the preset is not saved from a guess (the safety rule).
private struct Unread: Error {}

extension ConsoleMirror {
    /// The strip's ticked parts as a preset, nil until every value they hold was read. A part the strip lacks is left
    /// out. Saving reads the side that is open: a linked pair's partner is not asked.
    public func capture(_ strip: StripID, parts: Set<PresetPart>, name: String, matchWords: [String]) -> Preset? {
        var preset = Preset(name: name, matchWords: matchWords, stripKind: strip.kind)
        do {
            for part in PresetPart.allCases where parts.contains(part) && part.exists(on: strip) {
                try capture(part, of: strip, into: &preset)
            }
        } catch {
            return nil
        }
        return preset
    }

    /// false until the desk sent every value `part` saves: Save waits for the parts that are ticked.
    public func isReadForPreset(_ part: PresetPart, of strip: StripID) -> Bool {
        capture(strip, parts: [part], name: "", matchWords: []) != nil
    }

    private func capture(_ part: PresetPart, of strip: StripID, into preset: inout Preset) throws {
        switch part {
        case .input: preset.input = try captureInput(strip)
        case .eq: preset.eq = try captureEQ(strip)
        case .gate: preset.gate = try captureGate(strip)
        case .comp: preset.comp = try captureComp(strip)
        case .mix: preset.mix = try MixPart(faderDb: number(Catalog.fader(strip)), pan: Catalog.pan(strip).map(number))
        case .sends: preset.sends = try captureSends(strip)
        }
    }

    private func captureInput(_ strip: StripID) throws -> InputPart {
        let preamp = headamp(of: strip)
        let delay = Catalog.delay(strip)
        return InputPart(
            gainDb: try preamp.map { try number(Catalog.headampGain($0)) },
            phantom: try preamp.map { try flag(Catalog.headampPhantom($0)) },
            trimDb: try number(Catalog.trim(strip)),
            polarityFlipped: try Catalog.invert(strip).map(flag),
            delayOn: try delay.map { try flag($0.on) },
            delayMs: try delay.map { try number($0.time) })
    }

    private func captureEQ(_ strip: StripID) throws -> EQPart {
        let lowCut = try Catalog.lowCut(strip).map { LowCutPart(on: try flag($0.on), hz: try number($0.frequency)) }
        let bands = try (1...strip.eqBandCount).map { band -> BandPart in
            let specs = Catalog.eqBand(strip, band)
            return BandPart(
                type: try option(specs.type), hz: try number(specs.frequency), db: try number(specs.gain),
                q: try number(specs.q))
        }
        return EQPart(on: try flag(Catalog.eqOn(strip)), lowCut: lowCut, bands: bands)
    }

    private func captureKeyFilter(_ specs: KeySpecs) throws -> KeyFilterPart {
        KeyFilterPart(
            on: try flag(specs.filterOn), type: try option(specs.filterType), hz: try number(specs.filterFrequency))
    }

    private func captureGate(_ strip: StripID) throws -> GatePart {
        let gate = Catalog.gate(strip)
        return GatePart(
            on: try flag(gate.on), mode: try option(gate.mode), thresholdDb: try number(gate.threshold),
            rangeDb: try number(gate.range), attackMs: try number(gate.attack), holdMs: try number(gate.hold),
            releaseMs: try number(gate.release), keyFilter: try captureKeyFilter(Catalog.gateKey(strip)))
    }

    private func captureComp(_ strip: StripID) throws -> CompPart {
        let comp = Catalog.dynamics(strip)
        let position = try Catalog.dynamicsPosition(strip).map(option) ?? "POST"
        return CompPart(
            on: try flag(comp.on), mode: try option(comp.mode), thresholdDb: try number(comp.threshold),
            ratio: try option(comp.ratio), knee: try number(comp.knee), attackMs: try number(comp.attack),
            holdMs: try number(comp.hold), releaseMs: try number(comp.release), makeupDb: try number(comp.makeup),
            mixPercent: try number(comp.mix), detector: try option(comp.detector),
            envelope: try option(comp.envelope), auto: try flag(comp.auto), position: position,
            keyFilter: try captureKeyFilter(Catalog.dynamicsKey(strip)))
    }

    private func captureSends(_ strip: StripID) throws -> [String: SendPart] {
        guard let kind = strip.kind.sendTarget else { return [:] }
        var sends: [String: SendPart] = [:]
        for target in StripID.all(kind) {
            sends[String(target.number)] = SendPart(
                levelDb: try number(Catalog.sendLevel(from: strip, to: target)),
                on: try flag(Catalog.sendOn(from: strip, to: target)),
                tap: try Catalog.sendTap(from: strip, to: target).map(option))
        }
        return sends
    }

    /// Rounded to what a person would type: the desk's steps are far coarser than four digits, so the same step comes
    /// back on loading.
    private func number(_ spec: ParamSpec) throws -> Double {
        guard let value = value(spec) else { throw Unread() }
        guard value.isFinite, value != 0 else { return value }
        let unit = pow(10, floor(log10(abs(value))) - 3)
        return (value / unit).rounded() * unit
    }

    private func flag(_ spec: ParamSpec) throws -> Bool {
        guard let value = value(spec) else { throw Unread() }
        return value == 1
    }

    private func option(_ spec: ParamSpec) throws -> String {
        guard case .choice(let options) = spec.scale, let index = value(spec).map({ Int($0) }), options.indices.contains(index)
        else { throw Unread() }
        return options[index]
    }
}

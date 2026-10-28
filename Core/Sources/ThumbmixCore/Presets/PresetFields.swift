import Foundation

/// One value of a preset next to the desk control it belongs to on a given strip. Validation, loading and the
/// preset's own page all read a preset through these, so each rule exists once.
enum PresetValue: Equatable {
    case number(Double)
    case flag(Bool)
    case option(String)
}

struct PresetField {
    /// Where the value sits in the file ("eq.bands[2].hz"): what a refusal names.
    let path: String
    /// nil where the strip has no such control. Validation refuses that; a load leaves the value out.
    let spec: ParamSpec?
    let value: PresetValue
    /// Set on the values a load asks about before it writes them.
    let role: Role?

    enum Role { case gain, trim, phantom, polarity, compPosition }

    init(_ path: String, _ spec: ParamSpec?, _ value: PresetValue, role: Role? = nil) {
        self.path = path
        self.spec = spec
        self.value = value
        self.role = role
    }

    /// `value` as the number the spec's scale speaks (a switch is 0 or 1, a choice its index); nil for a choice that
    /// is not among the spec's options.
    var real: Double? {
        switch (value, spec?.scale) {
        case (.number(let number), _): return number
        case (.flag(let flag), _): return flag ? 1 : 0
        case (.option(let name), .choice(let options)?): return options.firstIndex(of: name).map(Double.init)
        default: return nil
        }
    }
}

extension Preset {
    /// The values of `part`, as the controls of `strip` hold them. `headamp` is the preamp feeding the strip; without
    /// one, gain and 48V have no control.
    func fields(of part: PresetPart, on strip: StripID, headamp: Int?) -> [PresetField] {
        switch part {
        case .input: input?.fields(on: strip, headamp: headamp) ?? []
        case .eq: eq?.fields(on: strip) ?? []
        case .gate: gate?.fields(on: strip) ?? []
        case .comp: comp?.fields(on: strip) ?? []
        case .mix: mix?.fields(on: strip) ?? []
        case .sends: sendFields(on: strip)
        }
    }

    private func sendFields(on strip: StripID) -> [PresetField] {
        guard let sends, let kind = strip.kind.sendTarget else { return [] }
        return sends.keys.compactMap(Int.init).sorted().flatMap { number -> [PresetField] in
            guard (1...kind.count).contains(number), let send = sends[String(number)] else { return [] }
            return send.fields(from: strip, to: StripID(kind, number), path: "sends.\(number)")
        }
    }
}

extension InputPart {
    func fields(on strip: StripID, headamp: Int?) -> [PresetField] {
        let delay = Catalog.delay(strip)
        return [
            gainDb.map { PresetField("input.gainDb", headamp.map(Catalog.headampGain), .number($0), role: .gain) },
            phantom.map {
                PresetField("input.phantom", headamp.map(Catalog.headampPhantom), .flag($0), role: .phantom)
            },
            trimDb.map { PresetField("input.trimDb", Catalog.trim(strip), .number($0), role: .trim) },
            polarityFlipped.map {
                PresetField("input.polarityFlipped", Catalog.invert(strip), .flag($0), role: .polarity)
            },
            delayOn.map { PresetField("input.delayOn", delay?.on, .flag($0)) },
            delayMs.map { PresetField("input.delayMs", delay?.time, .number($0)) },
        ].compactMap { $0 }
    }
}

extension EQPart {
    func fields(on strip: StripID) -> [PresetField] {
        let lowCutSpecs = Catalog.lowCut(strip)
        let lowCutFields = lowCut.map {
            [
                PresetField("eq.lowCut.on", lowCutSpecs?.on, .flag($0.on)),
                PresetField("eq.lowCut.hz", lowCutSpecs?.frequency, .number($0.hz)),
            ]
        }
        return [PresetField("eq.on", Catalog.eqOn(strip), .flag(on))] + (lowCutFields ?? [])
            + bands.enumerated().flatMap { index, band in band.fields(on: strip, number: index + 1) }
    }
}

extension BandPart {
    fileprivate func fields(on strip: StripID, number: Int) -> [PresetField] {
        let specs = number <= strip.eqBandCount ? Catalog.eqBand(strip, number) : nil
        let path = "eq.bands[\(number)]"
        return [
            PresetField(path + ".type", specs?.type, .option(type)),
            PresetField(path + ".hz", specs?.frequency, .number(hz)),
            PresetField(path + ".db", specs?.gain, .number(db)),
            PresetField(path + ".q", specs?.q, .number(q)),
        ]
    }
}

extension KeyFilterPart {
    fileprivate func fields(_ specs: KeySpecs, path: String) -> [PresetField] {
        [
            PresetField(path + ".on", specs.filterOn, .flag(on)),
            PresetField(path + ".type", specs.filterType, .option(type)),
            PresetField(path + ".hz", specs.filterFrequency, .number(hz)),
        ]
    }
}

extension GatePart {
    func fields(on strip: StripID) -> [PresetField] {
        let specs = strip.hasGate ? Catalog.gate(strip) : nil
        let main = [
            PresetField("gate.on", specs?.on, .flag(on)),
            PresetField("gate.mode", specs?.mode, .option(mode)),
            PresetField("gate.thresholdDb", specs?.threshold, .number(thresholdDb)),
            PresetField("gate.rangeDb", specs?.range, .number(rangeDb)),
            PresetField("gate.attackMs", specs?.attack, .number(attackMs)),
            PresetField("gate.holdMs", specs?.hold, .number(holdMs)),
            PresetField("gate.releaseMs", specs?.release, .number(releaseMs)),
        ]
        return main + (keyFilter?.fields(Catalog.gateKey(strip), path: "gate.keyFilter") ?? [])
    }
}

extension CompPart {
    func fields(on strip: StripID) -> [PresetField] {
        let specs = strip.hasDynamics ? Catalog.dynamics(strip) : nil
        let main = [
            PresetField("comp.on", specs?.on, .flag(on)),
            PresetField("comp.mode", specs?.mode, .option(mode)),
            PresetField("comp.thresholdDb", specs?.threshold, .number(thresholdDb)),
            PresetField("comp.ratio", specs?.ratio, .option(ratio)),
            PresetField("comp.knee", specs?.knee, .number(knee)),
            PresetField("comp.attackMs", specs?.attack, .number(attackMs)),
            PresetField("comp.holdMs", specs?.hold, .number(holdMs)),
            PresetField("comp.releaseMs", specs?.release, .number(releaseMs)),
            PresetField("comp.makeupDb", specs?.makeup, .number(makeupDb)),
            PresetField("comp.mixPercent", specs?.mix, .number(mixPercent)),
            PresetField("comp.detector", specs?.detector, .option(detector)),
            PresetField("comp.envelope", specs?.envelope, .option(envelope)),
            PresetField("comp.auto", specs?.auto, .flag(auto)),
            PresetField("comp.position", Catalog.dynamicsPosition(strip), .option(position), role: .compPosition),
        ]
        return main + (keyFilter?.fields(Catalog.dynamicsKey(strip), path: "comp.keyFilter") ?? [])
    }
}

extension MixPart {
    func fields(on strip: StripID) -> [PresetField] {
        [PresetField("mix.faderDb", Catalog.fader(strip), .number(faderDb))]
            + (pan.map { [PresetField("mix.pan", Catalog.pan(strip), .number($0))] } ?? [])
    }
}

extension SendPart {
    func fields(from strip: StripID, to target: StripID, path: String) -> [PresetField] {
        [
            PresetField(path + ".levelDb", Catalog.sendLevel(from: strip, to: target), .number(levelDb)),
            PresetField(path + ".on", Catalog.sendOn(from: strip, to: target), .flag(on)),
        ] + (tap.map { [PresetField(path + ".tap", Catalog.sendTap(from: strip, to: target), .option($0))] } ?? [])
    }
}

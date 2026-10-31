import Foundation

/// How a value shows in a result. Nothing is guessed: a control the desk never sent is JSON null.
enum ValueKind {
    case number(places: Int)
    case flag
    /// A choice by the desk's own name ("PEQ", "COMP").
    case option
    /// The ratio's N, as a number.
    case ratio
    /// A level in dB as the desk shows it; "-inf" when all the way down.
    case fader
    /// On = 1 is live, so muted is the other way round.
    case muted
}

extension DeskTools {
    func json(_ spec: ParamSpec, _ kind: ValueKind) -> JSON {
        guard let normalized = mirror.normalized(spec) else { return .null }
        let value = spec.scale.value(fromNormalized: normalized)
        switch kind {
        case .number(let places): return .number(Self.rounded(value, places))
        case .flag: return .bool(value >= 1)
        case .muted: return .bool(value < 1)
        case .option: return option(spec, index: value).map(JSON.string) ?? .null
        case .ratio: return option(spec, index: value).flatMap(Double.init).map(JSON.number) ?? .null
        case .fader:
            let level = FaderLaw.shownDecibels(fromWire: Double(normalized))
            return level.isFinite ? .number(Self.rounded(level, 1)) : "-inf"
        }
    }

    private func option(_ spec: ParamSpec, index: Double) -> String? {
        guard case .choice(let options) = spec.scale, options.indices.contains(Int(index)) else { return nil }
        return options[Int(index)]
    }

    /// No -0 in the output: JSON would print it.
    static func rounded(_ value: Double, _ places: Int) -> Double {
        let factor = pow(10, Double(places))
        let result = (value * factor).rounded() / factor
        return result == 0 ? 0 : result
    }

    // MARK: list_strips

    func runListStrips(_ arguments: ToolArguments) async throws -> JSON {
        try requireLive()
        let kind = try arguments.string("kind").map(stripKind(named:))
        let named = arguments.bool("named_only") ?? false
        let strips = StripKind.allCases.filter { kind == nil || $0 == kind }.flatMap(StripID.all)
            .filter { !named || !mirror.rawName($0).isEmpty }
        return ["strips": .array(strips.map { .object(summary($0)) })]
    }

    private func stripKind(named name: String) throws -> StripKind {
        guard let kind = StripKind.allCases.first(where: { Self.kindName($0) == name }) else {
            throw ToolError.invalid("'kind' must be one of \(Self.kinds.joined(separator: ", ")).")
        }
        return kind
    }

    nonisolated static func kindName(_ kind: StripKind) -> String {
        switch kind {
        case .input: "input"
        case .auxIn: "aux_in"
        case .fxReturn: "fx_return"
        case .bus: "bus"
        case .matrix: "matrix"
        case .mainStereo: "main_stereo"
        case .mainMono: "main_mono"
        case .dca: "dca"
        }
    }

    /// What every strip shows at a glance; `get_strip` adds the rest.
    func summary(_ strip: StripID) -> [String: JSON] {
        let partner = mirror.isLinked(strip) ? strip.partner : nil
        let muted = mirror.cell(strip.on).argument.map { $0 == .int(0) }
        return [
            "id": .string(StripLookup.id(of: strip)), "kind": .string(Self.kindName(strip.kind)),
            "name": .string(mirror.name(strip)), "named": .bool(!mirror.rawName(strip).isEmpty),
            "linked_with": partner.map { .string(StripLookup.id(of: $0)) } ?? .null,
            "fader_db": json(Catalog.fader(strip), .fader), "muted": muted.map(JSON.bool) ?? .null,
        ]
    }

    // MARK: get_strip

    func runGetStrip(_ arguments: ToolArguments) async throws -> JSON {
        try requireLive()
        let strip = try resolve(arguments.string("strip") ?? "")
        try await read([.eq, .comp, .gate], of: strip, needing: Self.detailSpecs(strip).map(\.address))
        try requireLive()
        var result = summary(strip)
        if let pan = Catalog.pan(strip) { result["pan"] = json(pan, .number(places: 0)) }
        if strip.eqBandCount > 0 { result["eq"] = eq(strip) }
        if strip.hasDynamics { result["comp"] = comp(strip) }
        if strip.hasGate { result["gate"] = gate(strip) }
        return .object(result)
    }

    /// Everything `get_strip` shows beyond the overview: what it waits for.
    private static func detailSpecs(_ strip: StripID) -> [ParamSpec] {
        let eq = strip.eqBandCount > 0 ? [Catalog.eqOn(strip)] + (1...strip.eqBandCount).flatMap { Catalog.eqBand(strip, $0).all } : []
        return eq + (strip.hasDynamics ? Catalog.dynamics(strip).all : []) + (strip.hasGate ? Catalog.gate(strip).all : [])
    }

    private func eq(_ strip: StripID) -> JSON {
        let bands = (1...strip.eqBandCount).map { number -> JSON in
            let band = Catalog.eqBand(strip, number)
            return [
                "band": .number(Double(number)), "type": json(band.type, .option),
                "freq_hz": json(band.frequency, .number(places: 1)), "gain_db": json(band.gain, .number(places: 2)),
                "q": json(band.q, .number(places: 2)),
            ]
        }
        return ["on": json(Catalog.eqOn(strip), .flag), "bands": .array(bands)]
    }

    private func comp(_ strip: StripID) -> JSON {
        let dynamics = Catalog.dynamics(strip)
        return [
            "on": json(dynamics.on, .flag), "mode": json(dynamics.mode, .option),
            "threshold_db": json(dynamics.threshold, .number(places: 1)), "ratio": json(dynamics.ratio, .ratio),
            "attack_ms": json(dynamics.attack, .number(places: 1)), "release_ms": json(dynamics.release, .number(places: 1)),
            "makeup_db": json(dynamics.makeup, .number(places: 1)), "auto_time": json(dynamics.auto, .flag),
            "mix_pct": json(dynamics.mix, .number(places: 0)),
        ]
    }

    private func gate(_ strip: StripID) -> JSON {
        let gate = Catalog.gate(strip)
        return [
            "on": json(gate.on, .flag), "mode": json(gate.mode, .option),
            "threshold_db": json(gate.threshold, .number(places: 1)), "range_db": json(gate.range, .number(places: 1)),
            "attack_ms": json(gate.attack, .number(places: 1)), "hold_ms": json(gate.hold, .number(places: 1)),
            "release_ms": json(gate.release, .number(places: 1)),
        ]
    }
}

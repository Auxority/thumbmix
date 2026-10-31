import Foundation

/// One value a write sets: the spec says where it goes and what the desk takes, the argument is what goes out.
struct Change {
    let label: String
    let spec: ParamSpec
    let argument: OSCArgument
    let kind: ValueKind

    /// A number in the spec's unit, snapped to the nearest step the desk has.
    static func number(_ label: String, _ spec: ParamSpec, _ value: Double, as kind: ValueKind) -> Change {
        Change(label: label, spec: spec, argument: Catalog.deskArguments([(spec, value)])[0].argument, kind: kind)
    }

    static func choice(_ label: String, _ spec: ParamSpec, index: Int, as kind: ValueKind) -> Change {
        Change(label: label, spec: spec, argument: .int(Int32(index)), kind: kind)
    }
}

extension DeskTools {
    // MARK: Fader and mute

    func runSetFader(_ arguments: ToolArguments) async throws -> JSON {
        try requireLive()
        let strip = try resolve(arguments.string("strip") ?? "")
        let change = Change.number("fader_db", Catalog.fader(strip), arguments.number("db") ?? 0, as: .fader)
        return try await commit(strip, [change])
    }

    func runSetMute(_ arguments: ToolArguments) async throws -> JSON {
        try requireLive()
        let strip = try resolve(arguments.string("strip") ?? "")
        let muted = arguments.bool("muted") ?? false
        return try await commit(strip, [.choice("muted", Catalog.on(strip), index: muted ? 0 : 1, as: .muted)])
    }

    // MARK: EQ

    func runSetEQBand(_ arguments: ToolArguments) async throws -> JSON {
        try requireLive()
        let strip = try resolve(arguments.string("strip") ?? "")
        guard strip.eqBandCount > 0 else { throw ToolError.invalid("\(mirror.name(strip)) has no EQ.") }
        let band = arguments.integer("band") ?? 0
        guard (1...strip.eqBandCount).contains(band) else {
            throw ToolError.invalid(
                "\(mirror.name(strip)) has \(strip.eqBandCount) EQ bands; band must be 1 to \(strip.eqBandCount).")
        }
        let specs = Catalog.eqBand(strip, band)
        let changes = try eqChanges(arguments, specs)
        guard !changes.isEmpty else { throw ToolError.invalid("Give at least one of gain_db, freq_hz, q or type.") }
        try await read([.eq], of: strip, needing: changes.map(\.spec.address) + [Catalog.eqOn(strip).address])
        var notes: [String] = []
        if mirror.cell(Catalog.eqOn(strip).address).argument == .int(0) {
            notes.append("The EQ of this strip is switched off on the desk, so the change is stored but not heard.")
        }
        return try await commit(strip, changes, notes: notes, extra: ["band": .number(Double(band))])
    }

    private func eqChanges(_ arguments: ToolArguments, _ specs: EQBandSpecs) throws -> [Change] {
        var changes: [Change] = []
        if let gain = arguments.number("gain_db") { changes.append(.number("gain_db", specs.gain, gain, as: .number(places: 2))) }
        if let frequency = arguments.number("freq_hz") {
            changes.append(.number("freq_hz", specs.frequency, frequency, as: .number(places: 1)))
        }
        if let q = arguments.number("q") { changes.append(.number("q", specs.q, q, as: .number(places: 2))) }
        if let type = arguments.string("type") { changes.append(try typeChange(type, specs.type)) }
        return changes
    }

    /// The desk's abbreviation or its full name, in any case.
    private func typeChange(_ name: String, _ spec: ParamSpec) throws -> Change {
        guard case .choice(let options) = spec.scale else { throw ToolError.invalid("This strip has no filter types.") }
        let wanted = name.lowercased()
        let names = spec.optionNames ?? options
        guard let index = options.indices.first(where: { options[$0].lowercased() == wanted || names[$0].lowercased() == wanted })
        else { throw ToolError.invalid("Unknown EQ type '\(name)'. This band takes: \(options.joined(separator: ", ")).") }
        return .choice("type", spec, index: index, as: .option)
    }

    // MARK: Compressor

    func runSetComp(_ arguments: ToolArguments) async throws -> JSON {
        try requireLive()
        let strip = try resolve(arguments.string("strip") ?? "")
        guard strip.hasDynamics else { throw ToolError.invalid("\(mirror.name(strip)) has no compressor.") }
        let changes = compChanges(arguments, Catalog.dynamics(strip))
        guard !changes.isEmpty else {
            throw ToolError.invalid("Give at least one of threshold_db, ratio, makeup_db, attack_ms, release_ms or on.")
        }
        try await read([.comp], of: strip, needing: changes.map(\.spec.address))
        return try await commit(strip, changes)
    }

    private func compChanges(_ arguments: ToolArguments, _ comp: DynamicsSpecs) -> [Change] {
        var changes: [Change] = []
        let numbers: [(String, ParamSpec, ValueKind)] = [
            ("threshold_db", comp.threshold, .number(places: 1)), ("makeup_db", comp.makeup, .number(places: 1)),
            ("attack_ms", comp.attack, .number(places: 1)), ("release_ms", comp.release, .number(places: 1)),
        ]
        for (name, spec, kind) in numbers {
            if let value = arguments.number(name) { changes.append(.number(name, spec, value, as: kind)) }
        }
        // The schema holds the ratio to the desk's twelve steps, so the lookup finds it.
        if let ratio = arguments.number("ratio"), let index = Catalog.ratios.firstIndex(where: { Double($0) == ratio }) {
            changes.append(.choice("ratio", comp.ratio, index: index, as: .ratio))
        }
        if let on = arguments.bool("on") { changes.append(.choice("on", comp.on, index: on ? 1 : 0, as: .flag)) }
        return changes
    }

    // MARK: Commit

    /// Writes all `changes` or none: a value the desk never sent refuses the whole write, since half an edit would
    /// leave the strip in a state nobody asked for. The reply shows each value before and after, as the desk holds it.
    func commit(
        _ strip: StripID, _ changes: [Change], notes: [String] = [], extra: [String: JSON] = [:]
    ) async throws -> JSON {
        try requireLive()
        let unread = changes.filter { mirror.cell($0.spec.address).argument == nil }
        guard unread.isEmpty else {
            throw ToolError.unavailable(
                "The desk's current value for \(unread.map(\.label).joined(separator: ", ")) of \(mirror.name(strip)) has not been "
                    + "read yet. Nothing was written: Thumbmix never writes over a value it has not read. Try again in a moment.")
        }
        let before = changes.map { json($0.spec, $0.kind) }
        let partner = partnerFollows(strip, changes[0].spec.address)
        for change in changes { mirror.set(change.spec.address, change.argument) }
        await waitUntilSent(changes.map(\.spec.address))
        var changed: [String: JSON] = [:]
        for (change, from) in zip(changes, before) { changed[change.label] = ["from": from, "to": json(change.spec, change.kind)] }
        var result = extra.merging([
            "strip": .string(StripLookup.id(of: strip)), "name": .string(mirror.name(strip)), "changed": .object(changed),
        ]) { $1 }
        if let partner { result["also_applied_to"] = .string(StripLookup.id(of: partner)) }
        if !notes.isEmpty { result["notes"] = .array(notes.map(JSON.string)) }
        return .object(result)
    }

    /// The partner of a linked pair the desk copies this edit to, as `ConsoleMirror.set` decides.
    private func partnerFollows(_ strip: StripID, _ address: String) -> StripID? {
        mirror.partnerAddress(of: address) == nil ? nil : strip.partner
    }
}

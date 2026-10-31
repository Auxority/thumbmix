import Foundation

/// The tools' names, descriptions and parameters: what a model reads to decide how to call them. Ranges come from
/// `Catalog`'s own specs, so the schema can't drift from what the desk takes.
extension DeskTools {
    static let kinds = StripKind.allCases.map(kindName)

    private static let stripParameter = ToolParameter(
        name: "strip",
        description: "The strip: an id from list_strips (\"ch/01\", \"bus/03\", \"main/st\", \"dca/2\") or its name on the desk "
            + "(\"Kick\"; case and accents don't matter, a part of a name works when only one strip fits).",
        kind: .string, isRequired: true)

    var listStrips: RemoteTool {
        RemoteTool(
            name: "list_strips",
            description: "List the console's strips (input channels, aux ins, FX returns, buses, matrices, main LR, main mono, "
                + "DCAs) with id, desk name, kind, linked partner, fader level in dB and mute. Start here to find the strip the "
                + "user means. fader_db is \"-inf\" for a fader all the way down; null means the desk has not reported it.",
            parameters: [
                ToolParameter(
                    name: "kind", description: "Only strips of this kind: \(Self.kinds.joined(separator: ", ")).", kind: .string),
                ToolParameter(
                    name: "named_only", description: "True: leave out strips that have no name on the desk.", kind: .boolean),
            ],
            isReadOnly: true, run: { [self] in try await runListStrips($0) })
    }

    var getStrip: RemoteTool {
        RemoteTool(
            name: "get_strip",
            description: "Read one strip's current settings in real units: fader (dB), mute, pan (-100 left to +100 right), EQ "
                + "(on, and per band: type, freq_hz, gain_db, q), compressor (on, mode, threshold_db, ratio as N:1, attack_ms, "
                + "release_ms, makeup_db, auto_time, mix_pct), on input channels the gate, and on inputs and aux ins the preamp "
                + "(gain_db, phantom_48v, shared_with: other strips on the same preamp, which share its gain; null when no "
                + "preamp feeds the strip; read only, no tool sets them). Call this before any relative "
                + "change (\"more bass\", \"more compression\") and move from the value it returns. A null value was not read "
                + "from the desk and is unknown. While auto_time is true the desk ignores attack and release. linked_with names "
                + "the stereo partner of a linked pair.",
            parameters: [Self.stripParameter], isReadOnly: true, run: { [self] in try await runGetStrip($0) })
    }

    var setFader: RemoteTool {
        RemoteTool(
            name: "set_fader",
            description: "Set a strip's fader to an absolute level in dB: -90 is all the way down (off), 0 is unity, +10 is the "
                + "maximum. Values outside are refused. For \"a bit louder\" read the level first and move 1 to 3 dB: the "
                + "change is audible at once. Returns the previous and the new level; the desk snaps to its own steps.",
            parameters: [
                Self.stripParameter,
                ToolParameter(name: "db", description: "Level in dB, -90 to 10.", kind: .number(-90...10), isRequired: true),
            ],
            isReadOnly: false, run: { [self] in try await runSetFader($0) })
    }

    var setMute: RemoteTool {
        RemoteTool(
            name: "set_mute",
            description: "Mute (muted: true) or unmute a strip. Returns the previous and the new state.",
            parameters: [
                Self.stripParameter,
                ToolParameter(name: "muted", description: "True mutes, false unmutes.", kind: .boolean, isRequired: true),
            ],
            isReadOnly: false, run: { [self] in try await runSetMute($0) })
    }

    var setEQBand: RemoteTool {
        RemoteTool(
            name: "set_eq_band",
            description: "Change one EQ band of a strip; give only what should change. Inputs, aux ins and FX returns have 4 bands "
                + "(band 1 is the lowest, usually a bass band), buses, matrices and the mains 6. Call get_strip first to see "
                + "which band sits where. gain_db -15 to +15 (positive boosts), freq_hz 20 to 20000, q 0.3 to 10 (a low q is "
                + "wide; only PEQ and VEQ bands use it), type PEQ (bell), VEQ (vintage bell), LShv, HShv (shelves), LCut, HCut "
                + "(mains and matrices also BU6 to LR24). Moves of 1 to 3 dB are usual; a change is audible at once. Values "
                + "outside the ranges are refused. Returns the previous and new values, as the desk holds them (it snaps to "
                + "its own steps).",
            parameters: [
                Self.stripParameter,
                ToolParameter(name: "band", description: "EQ band number, 1 to 6.", kind: .integer(1...6), isRequired: true),
                ToolParameter(name: "gain_db", description: "Gain in dB, -15 to 15.", kind: .number(-15...15)),
                ToolParameter(name: "freq_hz", description: "Frequency in Hz, 20 to 20000.", kind: .number(20...20_000)),
                ToolParameter(name: "q", description: "Q, 0.3 (wide) to 10 (narrow).", kind: .number(0.3...10)),
                ToolParameter(name: "type", description: "Filter type: PEQ, VEQ, LShv, HShv, LCut or HCut.", kind: .string),
            ],
            isReadOnly: false, run: { [self] in try await runSetEQBand($0) })
    }

    var setComp: RemoteTool {
        RemoteTool(
            name: "set_comp",
            description: "Change a strip's compressor; give only what should change. threshold_db -60 to 0 (lower compresses more "
                + "of the signal), ratio one of 1.1, 1.3, 1.5, 2, 2.5, 3, 4, 5, 7, 10, 20, 100 (N:1, higher compresses harder), "
                + "makeup_db 0 to 24 (raise it to win back the level compression takes), attack_ms 0 to 120, release_ms 5 to "
                + "4000 (both ignored while auto_time is on), on switches the compressor. For \"more compression\" read "
                + "get_strip, lower the threshold a few dB or step the ratio up once, and adjust makeup_db. Values outside the "
                + "ranges are refused. Returns the previous and new values.",
            parameters: [
                Self.stripParameter,
                ToolParameter(name: "threshold_db", description: "Threshold in dB, -60 to 0.", kind: .number(-60...0)),
                ToolParameter(
                    name: "ratio", description: "Ratio as N:1, one of the desk's twelve steps.",
                    kind: .numberChoice(Catalog.ratios.compactMap(Double.init))),
                ToolParameter(name: "makeup_db", description: "Makeup gain in dB, 0 to 24.", kind: .number(0...24)),
                ToolParameter(name: "attack_ms", description: "Attack in ms, 0 to 120.", kind: .number(0...120)),
                ToolParameter(name: "release_ms", description: "Release in ms, 5 to 4000.", kind: .number(5...4000)),
                ToolParameter(name: "on", description: "True switches the compressor on, false off.", kind: .boolean),
            ],
            isReadOnly: false, run: { [self] in try await runSetComp($0) })
    }
}

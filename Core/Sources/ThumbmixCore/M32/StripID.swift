import Foundation

public enum StripKind: String, CaseIterable, Sendable {
    case input, auxIn, fxReturn, bus, matrix, mainStereo, mainMono, dca

    public var count: Int {
        switch self {
        case .input: 32
        case .auxIn, .fxReturn, .dca: 8
        case .bus: 16
        case .matrix: 6
        case .mainStereo, .mainMono: 1
        }
    }

    /// The mixes this kind's `/mix/NN` sends feed: inputs, aux ins and FX returns feed the buses; buses and
    /// mains feed the matrices (doc p.32-37).
    public var sendTarget: StripKind? {
        switch self {
        case .input, .auxIn, .fxReturn: .bus
        case .bus, .mainStereo, .mainMono: .matrix
        case .matrix, .dca: nil
        }
    }

    /// The kinds a Fed by tab lists: those that send to this one, and for the mains every kind with an LR switch and
    /// a mono send (`mix/st`, `mix/mono`; doc p.25-31). Matrices can't feed the mains; they're fed by them.
    public var feeders: [StripKind] {
        switch self {
        case .mainStereo, .mainMono: [.input, .auxIn, .fxReturn, .bus]
        default: StripKind.allCases.filter { $0.sendTarget == self }
        }
    }
}

/// One channel strip on the console. `number` is 1-based, as printed on the desk.
public struct StripID: Hashable, Sendable, Identifiable {
    public let kind: StripKind
    public let number: Int

    public init(_ kind: StripKind, _ number: Int = 1) {
        self.kind = kind
        self.number = number
    }

    public static func all(_ kind: StripKind) -> [StripID] {
        (1...kind.count).map { StripID(kind, $0) }
    }

    public var id: String { prefix }

    /// DCAs are the only strips whose OSC number is not zero-padded.
    public var prefix: String {
        switch kind {
        case .input: "/ch/" + twoDigits
        case .auxIn: "/auxin/" + twoDigits
        case .fxReturn: "/fxrtn/" + twoDigits
        case .bus: "/bus/" + twoDigits
        case .matrix: "/mtx/" + twoDigits
        case .mainStereo: "/main/st"
        case .mainMono: "/main/m"
        case .dca: "/dca/\(number)"
        }
    }

    public var name: String { prefix + "/config/name" }
    public var color: String { prefix + "/config/color" }
    public var icon: String { prefix + "/config/icon" }
    public var fader: String { kind == .dca ? prefix + "/fader" : prefix + "/mix/fader" }
    public var on: String { kind == .dca ? prefix + "/on" : prefix + "/mix/on" }

    /// "To Main LR" (doc p.25-31); matrices, the mains and DCAs don't feed the main mix this way.
    public var mainLR: String? {
        [.input, .auxIn, .fxReturn, .bus].contains(kind) ? prefix + "/mix/st" : nil
    }

    /// The desk numbers its solo switches 01-80 through every strip, in `StripKind`'s order (doc p.64).
    public var solo: String {
        let before = StripKind.allCases.prefix { $0 != kind }.map(\.count).reduce(0, +)
        return "/-stat/solosw/" + String(format: "%02d", before + number)
    }

    public var pan: String? {
        [.input, .auxIn, .fxReturn, .bus, .mainStereo].contains(kind) ? prefix + "/mix/pan" : nil
    }

    public var dcaMask: String? {
        [.input, .auxIn, .fxReturn, .bus].contains(kind) ? prefix + "/grp/dca" : nil
    }

    public var hasGate: Bool { kind == .input }
    public var hasDynamics: Bool { [.input, .bus, .matrix, .mainStereo, .mainMono].contains(kind) }
    /// Channels, buses, matrices and the mains have an insert (doc p.26-37); aux ins and FX returns don't.
    public var hasInsert: Bool { [.input, .bus, .matrix, .mainStereo, .mainMono].contains(kind) }

    public var eqBandCount: Int {
        switch kind {
        case .input, .auxIn, .fxReturn: 4
        case .bus, .matrix, .mainStereo, .mainMono: 6
        case .dca: 0
        }
    }

    public var defaultName: String {
        switch kind {
        case .input: CoreStrings.text("Ch \(number)")
        case .auxIn: CoreStrings.text("Aux \(number)")
        case .fxReturn: CoreStrings.text("FX \(number)")
        case .bus: CoreStrings.text("Bus \(number)")
        case .matrix: CoreStrings.text("Matrix \(number)")
        case .mainStereo: CoreStrings.text("Main LR")
        case .mainMono: CoreStrings.text("Main M")
        case .dca: CoreStrings.text("DCA \(number)")
        }
    }

    private var twoDigits: String { String(format: "%02d", number) }
}

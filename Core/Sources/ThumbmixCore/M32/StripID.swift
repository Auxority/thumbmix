import Foundation

public enum StripKind: String, CaseIterable, Sendable {
    case input, auxIn, fxReturn, bus, mainStereo, mainMono, dca

    public var count: Int {
        switch self {
        case .input: 32
        case .auxIn, .fxReturn, .dca: 8
        case .bus: 16
        case .mainStereo, .mainMono: 1
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
        case .mainStereo: "/main/st"
        case .mainMono: "/main/m"
        case .dca: "/dca/\(number)"
        }
    }

    public var name: String { prefix + "/config/name" }
    public var color: String { prefix + "/config/color" }
    public var fader: String { kind == .dca ? prefix + "/fader" : prefix + "/mix/fader" }
    public var on: String { kind == .dca ? prefix + "/on" : prefix + "/mix/on" }

    public var pan: String? {
        [.input, .auxIn, .fxReturn, .bus, .mainStereo].contains(kind) ? prefix + "/mix/pan" : nil
    }

    public var dcaMask: String? {
        [.input, .auxIn, .fxReturn, .bus].contains(kind) ? prefix + "/grp/dca" : nil
    }

    public var sendsToBuses: Bool { [.input, .auxIn, .fxReturn].contains(kind) }
    public var hasGate: Bool { kind == .input }
    public var hasDynamics: Bool { [.input, .bus, .mainStereo, .mainMono].contains(kind) }

    /// Aux ins and FX returns have a 4-band EQ on the desk, but v1 shows only their header.
    public var eqBandCount: Int {
        switch kind {
        case .input: 4
        case .bus, .mainStereo, .mainMono: 6
        case .auxIn, .fxReturn, .dca: 0
        }
    }

    public var defaultName: String {
        switch kind {
        case .input: "Ch \(number)"
        case .auxIn: "Aux \(number)"
        case .fxReturn: "FX \(number)"
        case .bus: "Bus \(number)"
        case .mainStereo: "Main LR"
        case .mainMono: "Main M"
        case .dca: "DCA \(number)"
        }
    }

    private var twoDigits: String { String(format: "%02d", number) }
}

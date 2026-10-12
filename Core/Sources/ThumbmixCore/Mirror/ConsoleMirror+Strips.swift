import Foundation

extension ConsoleMirror {
    public func name(_ strip: StripID) -> String {
        let name = rawName(strip)
        return name.isEmpty ? strip.defaultName : name
    }

    public func color(_ strip: StripID) -> ConsoleColor {
        guard case .int(let index)? = cell(strip.color).argument else { return ConsoleColor(index: 0) }
        return ConsoleColor(index: Int(index))
    }

    public func icon(_ strip: StripID) -> ConsoleIcon {
        guard case .int(let number)? = cell(strip.icon).argument else { return ConsoleIcon.icon(1) }
        return ConsoleIcon.icon(Int(number))
    }

    /// Sends a strip's scribble-strip label in one go, cleaned to what the desk stores.
    public func edit(_ strip: StripID, name: String, color: ConsoleColor, icon: Int) {
        set(strip.name, .string(StripName.sanitized(name)))
        set(strip.color, .int(Int32(color.index)))
        set(strip.icon, .int(Int32(ConsoleIcon.icon(icon).number)))
    }

    public func normalized(_ spec: ParamSpec) -> Float? {
        cell(spec.address).argument.flatMap(spec.scale.normalized(from:))
    }

    /// Real units (dB, Hz, ms) or the option index; nil until the console sent it.
    public func value(_ spec: ParamSpec) -> Double? {
        normalized(spec).map(spec.scale.value(fromNormalized:))
    }

    public func isMuted(_ strip: StripID) -> Bool {
        cell(strip.on).argument == .int(0)
    }

    /// Unnamed and pulled all the way down: almost certainly not patched for this show.
    public func isUnused(_ strip: StripID) -> Bool {
        rawName(strip).isEmpty && (normalized(Catalog.fader(strip)) ?? 0) == 0
    }

    /// The headamp (0-127) feeding an input or aux in, or nil when it reads from an internal source or a line jack.
    public func headamp(of strip: StripID) -> Int? {
        guard let address = Catalog.headampIndex(strip), case .int(let index)? = cell(address).argument,
            (0...127).contains(index)
        else { return nil }
        return Int(index)
    }

    /// The other inputs and aux ins on the same preamp: they share its gain and 48V.
    public func stripsSharingHeadamp(with strip: StripID) -> [StripID] {
        guard let mine = headamp(of: strip) else { return [] }
        return Catalog.preampStrips.filter { $0 != strip && headamp(of: $0) == mine }
    }

    /// Bit 0 = DCA 1. The doc doesn't state the bit order; m32-probe section 4 checks it.
    public func isMember(_ strip: StripID, ofDCA dca: Int) -> Bool {
        guard let address = strip.dcaMask, case .int(let mask)? = cell(address).argument else {
            return false
        }
        return mask & (1 << (dca - 1)) != 0
    }

    public func dcaMembers(_ dca: Int) -> [StripID] {
        [StripKind.input, .auxIn, .fxReturn, .bus].flatMap(StripID.all).filter {
            isMember($0, ofDCA: dca)
        }
    }

    /// The name exactly as the desk holds it, empty when unnamed: what the edit sheet starts from.
    public func rawName(_ strip: StripID) -> String {
        guard case .string(let name)? = cell(strip.name).argument else { return "" }
        return name.trimmingCharacters(in: .whitespaces)
    }
}

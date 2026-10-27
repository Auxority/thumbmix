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

    /// nil for a strip without the switch, or one not read yet.
    public func isInMainLR(_ strip: StripID) -> Bool? {
        guard let address = strip.mainLR, case .int(let value)? = cell(address).argument else { return nil }
        return value == 1
    }

    /// One side of a linked pair is enough: the desk links `mix/st` with fader and mute (`LinkSection.faderMute`).
    public func setInMainLR(_ strip: StripID, _ inMix: Bool) {
        guard let address = strip.mainLR else { return }
        set(address, .int(inMix ? 1 : 0))
    }

    /// false while off or not read yet: the comp's Attack and Release stay usable until the desk says otherwise.
    public func isAutoTimeOn(_ strip: StripID) -> Bool {
        cell(Catalog.dynamics(strip).auto.address).argument == .int(1)
    }

    public func set(_ spec: ParamSpec, normalized: Float) {
        set(spec.address, spec.scale.argument(fromNormalized: normalized))
    }

    /// `value` is in the spec's own unit (dB, Hz, option index).
    public func set(_ spec: ParamSpec, value: Double) {
        set(spec, normalized: spec.scale.normalized(forValue: value))
    }

    /// Either side of a linked pair counts: half a pair soloed on the desk still sounds (2026-10-19).
    public func isSoloed(_ strip: StripID) -> Bool { isSoloed(.strip(strip, .full)) == true }

    /// A linked pair solos both sides: the doc doesn't say whether the desk links solo, and half a stereo source
    /// soloed is never wanted. Writing the partner too is harmless if the desk does copy it.
    public func toggleSolo(_ strip: StripID) {
        let soloed: OSCArgument = .int(isSoloed(strip) ? 0 : 1)
        for side in soloSides(strip) { set(side.solo, soloed) }
    }

    /// nil while a side is unread: the safety rule shows neither on nor off.
    public func isSoloed(_ item: OverviewItem) -> Bool? {
        let states = soloSides(item.held).map { cell($0.solo).argument }
        guard !states.contains(nil) else { return nil }
        return states.contains(.int(1))
    }

    public func setSolo(_ item: OverviewItem, _ on: Bool) {
        for side in soloSides(item.held) { set(side.solo, .int(on ? 1 : 0)) }
    }

    /// Soloed rows on the whole desk, a linked pair counted once.
    public var soloedCount: Int {
        StripKind.allCases.flatMap(StripID.all).filter { !(isLinked($0) && !$0.isOddSide) && isSoloed($0) }.count
    }

    /// The line under a soloed name, a cue beside its yellow that works without colour (option 2, 2026-10-19):
    /// "Ch 9-10 · Solo", or "Solo" where the name has no line under it.
    public static func soloCaption(_ base: String?) -> String {
        let solo = CoreStrings.text("Solo")
        guard let base, !base.isEmpty else { return solo }
        return "\(base) · \(solo)"
    }

    public var isExclusiveSolo: Bool { cell(Catalog.exclusiveSolo).argument == .int(1) }

    public func turnOffExclusiveSolo() { set(Catalog.exclusiveSolo, .int(0)) }

    /// The desk's CLEAR SOLO (doc p.69). Whether it pushes every switch it clears isn't documented, so all are re-read.
    public func clearSolo() {
        // Clear wins over a stroke still held (a second thumb on the bar): its holds would hide the cleared solos.
        abandonSoloStroke()
        command("/-action/clearsolo", .int(1))
        let now = ContinuousClock.now
        for strip in StripKind.allCases.flatMap(StripID.all) { holds.rereadSoon(strip.solo, now: now) }
    }

    /// An action the desk performs (CLEAR SOLO), not a value it keeps: no cell, nothing to show or hold.
    func command(_ address: String, _ argument: OSCArgument) {
        guard isLive else { return }
        pendingSends[address] = argument
    }

    /// Sends now what's waiting for the next tick: a send that must reach the desk before later ones (Exclusive solo
    /// off before the solos it would drop) can't wait in the batch, which leaves in no set order.
    func flushSends() {
        for (address, argument) in pendingSends { link.send(OSCMessage(address, [argument])) }
        pendingSends.removeAll()
    }

    /// Both sides of a linked pair, as solo writes them.
    func soloSides(_ strip: StripID) -> [StripID] {
        isLinked(strip) ? strip.oddSide.pairSides : [strip]
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

    /// `stripsSharingHeadamp` by name in one list ("Vox 2 and Ch 3"); nil when the input is the strip's alone.
    /// `other` is left out: a linked partner an alert already names as part of the pair.
    public func namesSharingHeadamp(
        with strip: StripID, besides other: StripID? = nil, locale: Locale = .current
    ) -> String? {
        let names = stripsSharingHeadamp(with: strip).filter { $0 != other }.map(name)
        return names.isEmpty ? nil : names.formatted(.list(type: .and).locale(locale))
    }

    /// The name exactly as the desk holds it, empty when unnamed: what the edit sheet starts from.
    public func rawName(_ strip: StripID) -> String {
        guard case .string(let name)? = cell(strip.name).argument else { return "" }
        return name.trimmingCharacters(in: .whitespaces)
    }
}

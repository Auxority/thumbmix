import Foundation
import Observation
import os

public enum MirrorStatus: Equatable, Sendable {
    case connecting
    case syncing(Double)
    case live
    case lost
    case failed(LinkFailure)
}

/// The app's copy of the console. Incoming OSC updates cells; edits update cells at once and go
/// out at most every 20 ms per address.
@MainActor @Observable
public final class ConsoleMirror {
    public internal(set) var status: MirrorStatus = .connecting
    public var isLive: Bool { status == .live }
    /// Sections whose partner didn't follow the app's edit this session; see ConsoleMirror+Link.
    public internal(set) var sectionsSeenUnlinked: Set<LinkSection> = []

    @ObservationIgnored private(set) var cells: [String: ParamCell] = [:]
    @ObservationIgnored let link: ConsoleLink
    @ObservationIgnored public let spectrum = SpectrumCell()
    /// Set while the app borrows the desk's RTA; see ConsoleMirror+RTA.
    @ObservationIgnored var rtaLoan: RTALoan?
    @ObservationIgnored private let addresses: [String]
    @ObservationIgnored private var meterCells: [StripID: MeterCell] = [:]
    @ObservationIgnored private var sync: InitialSync?
    @ObservationIgnored private var pendingSends: [String: OSCArgument] = [:]
    @ObservationIgnored var holds = EditHolds(hold: ConsoleMirror.editHold)
    @ObservationIgnored var linkCopies = LinkCopyCheck()
    @ObservationIgnored private let auditAddresses: [String]
    @ObservationIgnored private var auditIndex = 0
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private let log = Logger(subsystem: "thumbmix", category: "mirror")

    /// While the user drags, pushes for that control are ignored so it doesn't jump under the finger.
    static let editHold: Duration = .milliseconds(300)
    static let sendInterval: Duration = .milliseconds(20)

    /// `auditAddresses` are re-read one per tick while live, so a push that never arrived (lost renewal,
    /// console client limit) is corrected within seconds instead of showing a stale value as live.
    public init(
        link: ConsoleLink, addresses: [String] = Catalog.syncAddresses(),
        auditAddresses: [String] = Catalog.auditAddresses()
    ) {
        self.link = link
        self.addresses = addresses
        self.auditAddresses = auditAddresses
        for address in addresses { cells[address] = ParamCell() }
        for kind in StripKind.allCases {
            for strip in StripID.all(kind) { meterCells[strip] = MeterCell() }
        }
        // The doc doesn't say preamp routing is pushed, so it is re-read with every renewal.
        link.renewals =
            [OSCMessage("/xremote")] + MeterBanks.subscriptions
            + Catalog.headampIndexAddresses.map { OSCMessage($0) }
        link.onMessage = { [weak self] in self?.apply($0) }
        link.onState = { [weak self] in self?.linkChanged($0) }
    }

    public func start() {
        link.start()
        tasks.append(
            Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: Self.sendInterval)
                    guard let self else { return }
                    self.tick()
                }
            })
    }

    /// True while the send loop and link run; tests read it.
    var isRunning: Bool { !tasks.isEmpty }

    public func stop() {
        for task in tasks { task.cancel() }
        tasks = []
        link.stop()
    }

    public func cell(_ address: String) -> ParamCell {
        if let cell = cells[address] { return cell }
        log.error("no cell for \(address, privacy: .public); add it to Catalog.syncAddresses")
        let cell = ParamCell()
        cells[address] = cell
        return cell
    }

    public func meter(_ strip: StripID) -> MeterCell {
        meterCells[strip] ?? MeterCell()
    }

    public func set(_ address: String, _ argument: OSCArgument) {
        guard isLive else {
            log.notice(
                "edit ignored while \(String(describing: self.status), privacy: .public): \(address, privacy: .public)"
            )
            return
        }
        // Never act on a value the console never told us: a drag would start from a guess and jump the desk.
        guard cell(address).argument != nil else {
            log.notice("edit ignored for unread \(address, privacy: .public)")
            return
        }
        write(address, argument)
        if let partner = partnerAddress(of: address) { followLinkedEdit(partner, argument) }
    }

    /// The desk copies a shared section to the linked partner, but may not push that copy back: the partner is
    /// re-read and checked. A desk that turns out not to copy gets both sides written by the app.
    private func followLinkedEdit(_ partner: String, _ argument: OSCArgument) {
        guard linkCopies.deskCopies else {
            // Writing an unread partner would show a value the desk never sent.
            if cell(partner).argument != nil { write(partner, argument) }
            return
        }
        linkCopies.expect(partner, argument)
        holds.rereadSoon(partner, now: .now)
    }

    func write(_ address: String, _ argument: OSCArgument) {
        cell(address).argument = argument
        holds.edited(address, now: .now)
        pendingSends[address] = argument
    }

    /// The user's finger owns a control from touch-down until shortly after release.
    public func beginEdit(_ address: String) {
        holds.begin(address)
    }

    public func endEdit(_ address: String) {
        holds.end(address, now: .now)
    }

    public func wake() {
        link.wake()
    }

    func apply(_ message: OSCMessage) {
        if message.address == RTA.bank {
            applySpectrum(message)
            return
        }
        if message.address.hasPrefix("/meters/") {
            applyMeters(message)
            return
        }
        guard let cell = cells[message.address],
            let argument = message.arguments.first.flatMap(Self.sanitised)
        else { return }
        // A reply of another type (",i" where the parameter is ",f") is garbage, not a new value.
        if let known = cell.argument, !known.hasSameType(as: argument) { return }
        if sync != nil {
            sync?.received(message.address)
            pumpSync()
        }
        if holds.isHeld(message.address, now: .now) { return }
        store(argument, in: cell, at: message.address)
    }

    private func store(_ argument: OSCArgument, in cell: ParamCell, at address: String) {
        let old = cell.argument
        cell.argument = argument
        if let old, old != argument { linkSettingChanged(address) }
        guard let wanted = linkCopies.received(address, argument, now: .now), let section = linkSection(of: address)
        else { return }
        log.warning("\(address, privacy: .public) didn't follow a linked edit (\(section.rawValue, privacy: .public))")
        partnerDidNotFollow(address, wanted: wanted, section: section)
    }

    /// Every cell float is a 0...1 position; NaN or out-of-range values would crash or break the drawing.
    private static func sanitised(_ argument: OSCArgument) -> OSCArgument? {
        guard case .float(let value) = argument else { return argument }
        guard value.isFinite else { return nil }
        return .float(min(max(value, 0), 1))
    }

    private func applyMeters(_ message: OSCMessage) {
        guard case .blob(let blob)? = message.arguments.first else { return }
        let readings = MeterBanks.readings(
            address: message.address, values: MeterBlob.floats(from: blob))
        for (strip, reading) in readings {
            guard let cell = meterCells[strip] else { continue }
            // Explicit equality checks: older Observation versions notify on every write, which redraws idle meters at 20 Hz.
            if cell.level != reading.level { cell.level = reading.level }
            if let gate = reading.gateGain, cell.gateGain != gate { cell.gateGain = gate }
            if let dynamics = reading.dynamicsGain, cell.dynamicsGain != dynamics {
                cell.dynamicsGain = dynamics
            }
        }
    }

    private func tick() {
        for (address, argument) in pendingSends { link.send(OSCMessage(address, [argument])) }
        pendingSends.removeAll()
        if sync != nil { pumpSync() }
        guard isLive else { return }
        sendDueRereads()
        sendNextAudit()
    }

    private func sendDueRereads() {
        for address in holds.takeDueRereads(now: .now) {
            linkCopies.rereadSent(address, now: .now)
            link.send(OSCMessage(address))
        }
    }

    private func sendNextAudit() {
        guard !auditAddresses.isEmpty else { return }
        link.send(OSCMessage(auditAddresses[auditIndex]))
        auditIndex = (auditIndex + 1) % auditAddresses.count
    }

    private func linkChanged(_ state: LinkState) {
        switch state {
        case .connecting:
            status = .connecting
        case .live:
            startSync()
        case .lost:
            sync = nil
            linkCopies.forget()
            status = .lost
        case .failed(let failure):
            status = .failed(failure)
            // Nothing more will come from this console; don't keep a socket and a 50 Hz loop running.
            stop()
        }
    }

    private func startSync() {
        log.info("sync started: \(self.addresses.count) addresses")
        sync = InitialSync(addresses: addresses)
        // An edit made just before an outage may never have reached the console; the resync is the truth.
        holds.clearTimedHolds()
        linkCopies.forget()
        sectionsSeenUnlinked.removeAll()
        status = .syncing(0)
        pumpSync()
    }

    private func pumpSync() {
        guard let sync else { return }
        for address in sync.due(now: .now) { link.send(OSCMessage(address)) }
        guard sync.isDone else {
            let progress = (sync.progress * 100).rounded() / 100
            if status != .syncing(progress) { status = .syncing(progress) }
            return
        }
        if !sync.missing.isEmpty {
            log.warning("sync done; \(sync.missing.count) addresses never answered")
        }
        log.info("sync done")
        self.sync = nil
        status = .live
    }
}

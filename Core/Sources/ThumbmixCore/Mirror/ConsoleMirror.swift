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
    /// Read on connect; everything else is read per tab (`ConsoleMirror+Reads`) and forgotten on a resync.
    @ObservationIgnored private let overview: [String]
    @ObservationIgnored private let overviewSet: Set<String>
    @ObservationIgnored var reads = ReadQueue()
    @ObservationIgnored private var meterCells: [StripID: MeterCell] = [:]
    @ObservationIgnored var pendingSends: [String: OSCArgument] = [:]
    @ObservationIgnored var holds = EditHolds(hold: ConsoleMirror.editHold)
    @ObservationIgnored var linkCopies = LinkCopyCheck()
    @ObservationIgnored private let auditAddresses: [String]
    @ObservationIgnored private var auditIndex = 0
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored let log = Logger(subsystem: "thumbmix", category: "mirror")
    /// The engineer answered Keep to the Exclusive solo question for this desk; the App sets it per connection.
    @ObservationIgnored public var keepsExclusiveSolo = false
    /// Called each time the console answers as an M32: on connect, and again after an outage.
    @ObservationIgnored public var onIdentified: ((ConsoleInfo) -> Void)?

    /// While the user drags, pushes for that control are ignored so it doesn't jump under the finger.
    static let editHold: Duration = .milliseconds(300)
    static let sendInterval: Duration = .milliseconds(20)

    /// `auditAddresses` are re-read one per tick while live, so a push that never arrived (lost renewal,
    /// console client limit) is corrected within seconds instead of showing a stale value as live.
    public init(
        link: ConsoleLink, addresses: [String] = Catalog.allAddresses(),
        overview: [String] = Catalog.overviewAddresses(), auditAddresses: [String] = Catalog.auditAddresses()
    ) {
        self.link = link
        self.overview = overview
        overviewSet = Set(overview)
        self.auditAddresses = auditAddresses
        for address in addresses { cells[address] = ParamCell() }
        for kind in StripKind.allCases {
            for strip in StripID.all(kind) { meterCells[strip] = MeterCell() }
        }
        link.renewals = { [weak self] in self?.renewalMessages ?? [] }
        link.onMessage = { [weak self] in self?.apply($0.message, arrivedAt: $0.time) }
        link.onState = { [weak self] in self?.linkChanged($0) }
    }

    /// What the link re-sends every few seconds: the doc doesn't say preamp routing is pushed, so it is re-read here;
    /// the RTA stream only while the app borrows the RTA.
    private var renewalMessages: [OSCMessage] {
        [OSCMessage("/xremote")] + MeterBanks.subscriptions + Catalog.headampIndexAddresses.map { OSCMessage($0) }
            + (rtaLoan == nil ? [] : [RTA.subscription])
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
        log.error("no cell for \(address, privacy: .public); add it to Catalog.allAddresses")
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

    func apply(_ message: OSCMessage, arrivedAt arrival: ContinuousClock.Instant = .now) {
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
        // Stored before the reply is counted: the last answer turns the status live, and screens rebuild on that.
        if !holds.isHeld(message.address, now: .now) { store(argument, in: cell, at: message.address, arrivedAt: arrival) }
        noteReply(message.address)
    }

    /// A reply the connect sync or a tab read asked for frees a slot for the next request.
    private func noteReply(_ address: String) {
        if reads.received(address) { pumpReads() }
    }

    private func store(
        _ argument: OSCArgument, in cell: ParamCell, at address: String, arrivedAt arrival: ContinuousClock.Instant
    ) {
        let old = cell.argument
        cell.argument = argument
        if let old, old != argument { linkSettingChanged(address) }
        judgeLinkCopy(address, argument, arrivedAt: arrival)
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
        if isSyncing { pumpReads() }
        guard isLive else { return }
        pumpReads()
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
        case .live(let info):
            onIdentified?(info)
            startSync()
        case .lost:
            reads = ReadQueue()
            linkCopies.forget()
            status = .lost
        case .failed(let failure):
            status = .failed(failure)
            // Nothing more will come from this console; don't keep a socket and a 50 Hz loop running.
            stop()
        }
    }

    private var isSyncing: Bool {
        if case .syncing = status { return true }
        return false
    }

    private func startSync() {
        log.info("sync started: \(self.overview.count) addresses")
        forgetTabValues()
        reads = ReadQueue()
        reads.add(overview, urgent: false)
        // An edit made just before an outage may never have reached the console; the resync is the truth.
        holds.clearTimedHolds()
        linkCopies.forget()
        sectionsSeenUnlinked.removeAll()
        status = .syncing(0)
        pumpReads()
    }

    /// The last overview reply is stored before it is counted (see `apply`), so going live here never shows an unread value.
    private func finishSyncIfDone() {
        guard reads.isIdle else {
            let progress = (Double(reads.answered) / Double(overview.count) * 100).rounded() / 100
            if status != .syncing(progress) { status = .syncing(progress) }
            return
        }
        if !reads.missing.isEmpty {
            log.warning("sync done; \(self.reads.missing.count) addresses never answered")
        }
        log.info("sync done")
        status = .live
        startBackgroundFill()
        pumpReads()
    }

    /// A value read before an outage may have changed on the desk meanwhile; the open tab reads it again once live.
    private func forgetTabValues() {
        for (address, cell) in cells where !overviewSet.contains(address) && cell.argument != nil { cell.argument = nil }
    }

    func pumpReads() {
        let missing = reads.missing.count
        for address in reads.due(now: .now) { link.send(OSCMessage(address)) }
        if isSyncing {
            finishSyncIfDone()
        } else if reads.missing.count > missing {
            log.warning("\(self.reads.missing.count - missing) tab values never answered; their rows stay disabled")
        }
    }
}

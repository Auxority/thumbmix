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
    public private(set) var status: MirrorStatus = .connecting
    public var isLive: Bool { status == .live }

    @ObservationIgnored private(set) var cells: [String: ParamCell] = [:]
    @ObservationIgnored private let link: ConsoleLink
    @ObservationIgnored private let addresses: [String]
    @ObservationIgnored private var meterCells: [StripID: MeterCell] = [:]
    @ObservationIgnored private var sync: InitialSync?
    @ObservationIgnored private var pendingSends: [String: OSCArgument] = [:]
    @ObservationIgnored private var heldUntil: [String: ContinuousClock.Instant] = [:]
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private let log = Logger(subsystem: "thumbmix", category: "mirror")

    /// While the user drags, pushes for that control are ignored so it doesn't jump under the finger.
    static let editHold: Duration = .milliseconds(300)
    static let sendInterval: Duration = .milliseconds(20)

    public init(link: ConsoleLink, addresses: [String] = Catalog.syncAddresses()) {
        self.link = link
        self.addresses = addresses
        for address in addresses { cells[address] = ParamCell() }
        for kind in StripKind.allCases {
            for strip in StripID.all(kind) { meterCells[strip] = MeterCell() }
        }
        // The doc doesn't say preamp routing is pushed, so it is re-read with every renewal.
        link.renewals = [OSCMessage("/xremote")] + MeterBanks.subscriptions
            + Catalog.headampIndexAddresses.map { OSCMessage($0) }
        link.onMessage = { [weak self] in self?.apply($0) }
        link.onState = { [weak self] in self?.linkChanged($0) }
    }

    public func start() {
        link.start()
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.sendInterval)
                self?.tick()
            }
        })
    }

    public func stop() {
        tasks.forEach { $0.cancel() }
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
            log.notice("edit ignored while \(String(describing: self.status), privacy: .public): \(address, privacy: .public)")
            return
        }
        cell(address).argument = argument
        heldUntil[address] = .now + Self.editHold
        pendingSends[address] = argument
    }

    func apply(_ message: OSCMessage) {
        if message.address.hasPrefix("/meters/") {
            applyMeters(message)
            return
        }
        guard let cell = cells[message.address], let argument = message.arguments.first else { return }
        if sync != nil {
            sync?.received(message.address)
            pumpSync()
        }
        if let held = heldUntil[message.address], held > .now { return }
        cell.argument = argument
    }

    private func applyMeters(_ message: OSCMessage) {
        guard case let .blob(blob)? = message.arguments.first else { return }
        let readings = MeterBanks.readings(address: message.address, values: MeterBlob.floats(from: blob))
        for (strip, reading) in readings {
            guard let cell = meterCells[strip] else { continue }
            cell.level = reading.level
            if let gate = reading.gateGain { cell.gateGain = gate }
            if let dynamics = reading.dynamicsGain { cell.dynamicsGain = dynamics }
        }
    }

    private func tick() {
        for (address, argument) in pendingSends { link.send(OSCMessage(address, [argument])) }
        pendingSends.removeAll()
        if sync != nil { pumpSync() }
    }

    private func linkChanged(_ state: LinkState) {
        switch state {
        case .connecting:
            status = .connecting
        case .live:
            startSync()
        case .lost:
            sync = nil
            status = .lost
        case let .failed(failure):
            status = .failed(failure)
        }
    }

    private func startSync() {
        log.info("sync started: \(self.addresses.count) addresses")
        sync = InitialSync(addresses: addresses)
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
        if !sync.missing.isEmpty { log.warning("sync done; \(sync.missing.count) addresses never answered") }
        log.info("sync done")
        self.sync = nil
        status = .live
    }
}

import Foundation
import os

public struct ConsoleInfo: Equatable, Sendable {
    public let model: String
    public let firmware: String
}

public enum LinkFailure: Equatable, Sendable {
    case noReply
    case notAnM32(model: String)
}

public enum LinkState: Equatable, Sendable {
    case connecting
    case live(ConsoleInfo)
    case lost
    case failed(LinkFailure)
}

public struct LinkTiming: Sendable {
    public var identifyTimeout: Duration
    public var tick: Duration
    public var renewEvery: Duration
    public var probeWhenQuietFor: Duration
    public var lostAfter: Duration
    public var restartAfterLost: Duration

    public init(
        identifyTimeout: Duration, tick: Duration, renewEvery: Duration, probeWhenQuietFor: Duration,
        lostAfter: Duration, restartAfterLost: Duration
    ) {
        self.identifyTimeout = identifyTimeout
        self.tick = tick
        self.renewEvery = renewEvery
        self.probeWhenQuietFor = probeWhenQuietFor
        self.lostAfter = lostAfter
        self.restartAfterLost = restartAfterLost
    }

    /// `/xremote` and `/meters` expire after 10 s (doc p.9, p.16). Renewing every 4 s fits two renewals
    /// in that window, so one lost UDP packet doesn't lapse the subscription.
    public static let console = LinkTiming(
        identifyTimeout: .seconds(3), tick: .milliseconds(500),
        renewEvery: .seconds(4), probeWhenQuietFor: .seconds(1), lostAfter: .seconds(3),
        restartAfterLost: .seconds(5)
    )
}

/// Owns the socket to one console: checks it is an M32, keeps subscriptions alive and notices silence.
@MainActor
public final class ConsoleLink {
    public private(set) var state: LinkState = .connecting {
        didSet {
            guard state != oldValue else { return }
            log.info("link \(String(describing: self.state), privacy: .public)")
            onState?(state)
        }
    }

    public var onMessage: ((OSCMessage) -> Void)?
    public var onState: ((LinkState) -> Void)?
    /// Re-sent every `renewEvery`, and at once when the console comes back.
    public var renewals: [OSCMessage] = [OSCMessage("/xremote")]

    /// Bumped each time the socket is rebuilt; tests read it.
    private(set) var transportGeneration = 0

    private let host: String
    private let port: UInt16
    private var transport: UDPTransport
    private var receiveTask: Task<Void, Never>?
    private let timing: LinkTiming
    private let log = Logger(subsystem: "thumbmix", category: "link")
    private var info: ConsoleInfo?
    private var supervisor: LinkSupervisor
    private var tasks: [Task<Void, Never>] = []
    private var isStopped = false

    public init(host: String, port: UInt16 = 10023, timing: LinkTiming = .console) {
        self.host = host
        self.port = port
        transport = UDPTransport(host: host, port: port)
        self.timing = timing
        supervisor = LinkSupervisor(timing: timing, now: .now)
    }

    public func start() {
        startTransport()
        tasks.append(Task { [weak self] in await self?.identify() })
    }

    /// After the app was in the background: desk changes may have been missed and the socket may be
    /// dead, so show the link as lost and rebuild it; the next reply makes it live and triggers a resync.
    /// A stopped link stays stopped: the mirror stops one that found no M32, and nothing would stop it again.
    public func wake() {
        guard info != nil, !isStopped else { return }
        if case .live = state { state = .lost }
        restartTransport()
    }

    public func send(_ message: OSCMessage) {
        transport.send(message)
    }

    public func stop() {
        isStopped = true
        for task in tasks { task.cancel() }
        tasks = []
        receiveTask?.cancel()
        transport.cancel()
    }

    private func startTransport() {
        transport.start()
        let messages = transport.messages
        receiveTask = Task { [weak self] in
            for await message in messages { self?.received(message) }
        }
    }

    /// iOS can leave a UDP connection dead after Wi-Fi loss or suspension without reporting it,
    /// so a link that stays lost gets a fresh socket.
    private func restartTransport() {
        log.info("rebuilding socket to \(self.host, privacy: .public)")
        receiveTask?.cancel()
        transport.cancel()
        transport = UDPTransport(host: host, port: port)
        transportGeneration += 1
        supervisor.restarted(at: .now)
        startTransport()
        transport.send(OSCMessage("/info"))
    }

    private func received(_ message: OSCMessage) {
        supervisor.heard(at: .now)
        if state == .lost, let info {
            state = .live(info)
            renew()
        }
        if message.address == "/info" {
            recordInfo(message)
            return
        }
        onMessage?(message)
    }

    private func recordInfo(_ message: OSCMessage) {
        guard info == nil, let model = message.string(at: 2) else { return }
        info = ConsoleInfo(model: model, firmware: message.string(at: 3) ?? "unknown")
    }

    private func identify() async {
        let deadline = ContinuousClock.now + timing.identifyTimeout
        while info == nil, ContinuousClock.now < deadline, !Task.isCancelled {
            transport.send(OSCMessage("/info"))
            try? await Task.sleep(for: timing.tick)
        }
        // stop() may have landed mid-identify; going live now would start a supervise loop nobody owns.
        guard !Task.isCancelled else { return }
        guard let info else {
            state = .failed(.noReply)
            return
        }
        guard info.model.hasPrefix("M32") else {
            state = .failed(.notAnM32(model: info.model))
            return
        }
        state = .live(info)
        renew()
        tasks.append(Task { [weak self] in await self?.supervise() })
    }

    /// One loop carries out the supervisor's decisions, so renewals and liveness can't drift apart.
    private func supervise() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: timing.tick)
            let isLive = if case .live = state { true } else { false }
            let actions = supervisor.tick(now: .now, isLive: isLive, isLost: state == .lost)
            if actions.markLost { state = .lost }
            if actions.restartSocket { restartTransport() }
            if actions.probe { transport.send(OSCMessage("/info")) }
            if actions.renew { renew() }
        }
    }

    private func renew() {
        supervisor.renewed(at: .now)
        renewals.forEach(transport.send)
    }
}

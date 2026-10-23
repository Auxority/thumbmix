import Foundation
import os

public struct ConsoleInfo: Equatable, Sendable {
    /// The network name set on the desk under Setup → Network.
    public let name: String
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

    public var onMessage: ((Arrival) -> Void)?
    public var onState: ((LinkState) -> Void)?
    /// Asked for on every renewal, so its owner (the mirror) decides what is subscribed; re-sent every `renewEvery`,
    /// and at once when the console comes back.
    public var renewals: () -> [OSCMessage] = { [OSCMessage("/xremote")] }

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
            // A replaced socket's stream still hands out what it buffered: replies from before the outage,
            // which would land after the resync forgot those values and show them as live.
            for await arrival in messages where !Task.isCancelled { self?.received(arrival) }
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
        transport.send(OSCMessage(Self.identity))
    }

    private func received(_ arrival: Arrival) {
        supervisor.heard(at: .now)
        if state == .lost, let info {
            state = .live(info)
            renew()
        }
        if arrival.message.address == Self.identity {
            recordInfo(arrival.message)
            return
        }
        onMessage?(arrival)
    }

    /// `/xinfo`, not `/info`: both carry the model and firmware in the same slots, and only `/xinfo` carries
    /// the desk's own name (p.10), which the Connect screen remembers a console by.
    private static let identity = "/xinfo"

    private func recordInfo(_ message: OSCMessage) {
        guard info == nil, let model = message.string(at: 2) else { return }
        info = ConsoleInfo(
            name: message.string(at: 1) ?? host, model: model, firmware: message.string(at: 3) ?? "unknown")
    }

    private func identify() async {
        let deadline = ContinuousClock.now + timing.identifyTimeout
        while info == nil, ContinuousClock.now < deadline, !Task.isCancelled {
            transport.send(OSCMessage(Self.identity))
            await awaitInfo(until: min(ContinuousClock.now + timing.tick, deadline))
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

    /// Resent every tick but looked for every 10 ms: the desk answers within milliseconds, and going live only at
    /// the next tick made every connect ~0.5 s slower.
    private func awaitInfo(until resend: ContinuousClock.Instant) async {
        while info == nil, ContinuousClock.now < resend, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// One loop carries out the supervisor's decisions, so renewals and liveness can't drift apart.
    private func supervise() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: timing.tick)
            let isLive = if case .live = state { true } else { false }
            let actions = supervisor.tick(now: .now, isLive: isLive, isLost: state == .lost)
            if actions.markLost { state = .lost }
            if actions.restartSocket { restartTransport() }
            if actions.probe { transport.send(OSCMessage(Self.identity)) }
            if actions.renew { renew() }
        }
    }

    private func renew() {
        supervisor.renewed(at: .now)
        renewals().forEach(transport.send)
    }
}

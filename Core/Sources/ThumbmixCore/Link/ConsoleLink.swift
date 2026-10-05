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

    public init(identifyTimeout: Duration, tick: Duration, renewEvery: Duration, probeWhenQuietFor: Duration, lostAfter: Duration) {
        self.identifyTimeout = identifyTimeout
        self.tick = tick
        self.renewEvery = renewEvery
        self.probeWhenQuietFor = probeWhenQuietFor
        self.lostAfter = lostAfter
    }

    /// `/xremote` and `/meters` expire after 10 s on the console (doc p.9, p.16), hence the 9 s renewal.
    public static let console = LinkTiming(
        identifyTimeout: .seconds(3), tick: .milliseconds(500),
        renewEvery: .seconds(9), probeWhenQuietFor: .seconds(1), lostAfter: .seconds(3)
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

    private let transport: UDPTransport
    private let timing: LinkTiming
    private let log = Logger(subsystem: "thumbmix", category: "link")
    private var info: ConsoleInfo?
    private var lastHeard = ContinuousClock.now
    private var lastRenewal = ContinuousClock.now
    private var tasks: [Task<Void, Never>] = []

    public init(host: String, port: UInt16 = 10023, timing: LinkTiming = .console) {
        transport = UDPTransport(host: host, port: port)
        self.timing = timing
    }

    public func start() {
        transport.start()
        let messages = transport.messages
        tasks.append(Task { [weak self] in
            for await message in messages { self?.received(message) }
        })
        tasks.append(Task { [weak self] in await self?.identify() })
    }

    public func send(_ message: OSCMessage) {
        transport.send(message)
    }

    public func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
        transport.cancel()
    }

    private func received(_ message: OSCMessage) {
        lastHeard = .now
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

    /// One loop owns renewals and liveness so their timing can't drift apart.
    private func supervise() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: timing.tick)
            let now = ContinuousClock.now
            let quiet = now - lastHeard
            if quiet > timing.lostAfter, case .live = state { state = .lost }
            // An idle console sends nothing, so ask for something before deciding it is gone.
            if quiet > timing.probeWhenQuietFor { transport.send(OSCMessage("/info")) }
            if now - lastRenewal >= timing.renewEvery { renew() }
        }
    }

    private func renew() {
        lastRenewal = .now
        renewals.forEach(transport.send)
    }
}

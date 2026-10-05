import Foundation
import os

public struct DiscoveredConsole: Equatable, Sendable, Identifiable {
    public let host: String
    public let name: String
    public let model: String
    public var id: String { host }
}

/// Finds consoles by asking every address on the phone's /24 for `/xinfo`. Broadcast would need
/// Apple's multicast entitlement, which a free Apple ID can't get; unicast needs no entitlement.
public enum Discovery {
    private static let log = Logger(subsystem: "thumbmix", category: "discovery")

    public static func isValidIPv4(_ host: String) -> Bool {
        var address = in_addr()
        return inet_pton(AF_INET, host, &address) == 1
    }

    public static func sweepHosts(around ip: String) -> [String] {
        guard isValidIPv4(ip) else { return [] }
        let network = ip.split(separator: ".").prefix(3).joined(separator: ".")
        return (1...254).map { "\(network).\($0)" }.filter { $0 != ip }
    }

    /// The Wi-Fi interface's IPv4 address (`en0` on iPhone).
    public static func localIPv4() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard String(cString: interface.ifa_name) == "en0",
                  let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) else { continue }
            return address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ipString($0.pointee.sin_addr) }
        }
        return nil
    }

    public static func scan(hosts: [String], port: UInt16 = 10023, timeout: TimeInterval = 1.5) async -> [DiscoveredConsole] {
        await Task.detached { blockingScan(hosts: hosts, port: port, timeout: timeout) }.value
    }

    private static func blockingScan(hosts: [String], port: UInt16, timeout: TimeInterval) -> [DiscoveredConsole] {
        let socketHandle = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketHandle >= 0 else {
            log.error("discovery socket failed: errno \(errno)")
            return []
        }
        defer { close(socketHandle) }

        let request = [UInt8](OSCCodec.encode(OSCMessage("/xinfo")))
        for host in hosts { sendRequest(request, to: host, port: port, on: socketHandle) }

        var found: [String: DiscoveredConsole] = [:]
        let deadline = Date().addingTimeInterval(timeout)
        while deadline.timeIntervalSinceNow > 0 {
            guard let (host, reply) = receiveReply(on: socketHandle, until: deadline) else { break }
            guard reply.address == "/xinfo" else { continue }
            found[host] = DiscoveredConsole(host: host, name: reply.string(at: 1) ?? host, model: reply.string(at: 2) ?? "?")
        }
        log.info("discovery: \(found.count) consoles from \(hosts.count) hosts")
        return found.values.sorted { $0.host < $1.host }
    }

    private static func sendRequest(_ request: [UInt8], to host: String, port: UInt16, on socketHandle: Int32) {
        var destination = sockaddr_in()
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &destination.sin_addr) == 1 else { return }
        _ = withUnsafePointer(to: &destination) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(socketHandle, request, request.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    /// The next decodable reply and its sender, or nil once the deadline passes.
    private static func receiveReply(on socketHandle: Int32, until deadline: Date) -> (String, OSCMessage)? {
        var buffer = [UInt8](repeating: 0, count: 1500)
        while deadline.timeIntervalSinceNow > 0 {
            var poller = pollfd(fd: socketHandle, events: Int16(POLLIN), revents: 0)
            guard poll(&poller, 1, Int32(deadline.timeIntervalSinceNow * 1000)) > 0 else { return nil }
            var sender = sockaddr_in()
            var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &sender) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(socketHandle, &buffer, buffer.count, 0, $0, &senderLength)
                }
            }
            if count > 0, let reply = try? OSCCodec.decode(Data(buffer[0..<count])) {
                return (ipString(sender.sin_addr), reply)
            }
        }
        return nil
    }

    private static func ipString(_ address: in_addr) -> String {
        var address = address
        var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &address, &text, socklen_t(INET_ADDRSTRLEN))
        return String(decoding: text.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

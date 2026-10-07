import Foundation
import Network
import XCTest

/// Plays the engineer changing a setting on the desk: one OSC int set to the fake-m32 the app is connected to.
/// The UI tests don't link the app's OSC code, so this encodes the one message shape it needs by hand.
enum DeskChange {
    static func set(_ address: String, _ value: Int32) {
        let connection = NWConnection(host: "127.0.0.1", port: 10023, using: .udp)
        let sent = XCTestExpectation(description: "sent \(address)")
        connection.start(queue: .main)
        connection.send(content: message(address, value), completion: .contentProcessed { _ in sent.fulfill() })
        XCTWaiter().wait(for: [sent], timeout: 2)
        connection.cancel()
    }

    /// OSC strings end with a NUL and pad to 4 bytes; an int is 4 big-endian bytes (OSC 1.0).
    private static func message(_ address: String, _ value: Int32) -> Data {
        var data = padded(address) + padded(",i")
        withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
        return data
    }

    private static func padded(_ text: String) -> Data {
        var data = Data(text.utf8)
        data.append(contentsOf: [UInt8](repeating: 0, count: 4 - data.count % 4))
        return data
    }
}

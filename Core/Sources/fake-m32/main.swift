import FakeM32
import Foundation

// The simulator shares the Mac's localhost, so the app connects to 127.0.0.1.
let port = CommandLine.arguments.dropFirst().first.flatMap(UInt16.init) ?? 10023
let fake = try FakeM32(port: port)
let bound = try await fake.start()
print("Fake M32 listening on 127.0.0.1:\(bound). Ctrl-C stops it.")
while true { try await Task.sleep(for: .seconds(3600)) }

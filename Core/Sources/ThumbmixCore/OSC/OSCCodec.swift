import Foundation

public enum OSCDecodeError: Error, Equatable {
    case truncated
    case unterminatedString
    case unsupportedType(Character)
}

/// The OSC subset the M32 speaks: big-endian, 4-byte aligned, type tags i/f/s/b only.
public enum OSCCodec {
    public static func encode(_ message: OSCMessage) -> Data {
        var out = Data()
        appendString(message.address, to: &out)
        // The console accepts requests without a type tag; that is how its own tools send gets.
        guard !message.arguments.isEmpty else { return out }
        appendString("," + message.arguments.map(\.typeTag).joined(), to: &out)
        for argument in message.arguments {
            switch argument {
            case .int(let value): appendUInt32(UInt32(bitPattern: value), to: &out)
            case .float(let value): appendUInt32(value.bitPattern, to: &out)
            case .string(let value): appendString(value, to: &out)
            case .blob(let value):
                appendUInt32(UInt32(value.count), to: &out)
                out.append(value)
                padToFour(&out)
            }
        }
        return out
    }

    public static func decode(_ data: Data) throws -> OSCMessage {
        var reader = Reader(bytes: [UInt8](data))
        let address = try reader.string()
        guard reader.hasMore, reader.peek == UInt8(ascii: ",") else { return OSCMessage(address) }
        let tags = try reader.string().dropFirst()
        var arguments: [OSCArgument] = []
        for tag in tags {
            switch tag {
            case "i": arguments.append(.int(Int32(bitPattern: try reader.uint32())))
            case "f": arguments.append(.float(Float(bitPattern: try reader.uint32())))
            case "s": arguments.append(.string(try reader.string()))
            case "b": arguments.append(.blob(try reader.blob()))
            default: throw OSCDecodeError.unsupportedType(tag)
            }
        }
        return OSCMessage(address, arguments)
    }

    private static func appendString(_ value: String, to out: inout Data) {
        out.append(contentsOf: Array(value.utf8))
        out.append(0)
        padToFour(&out)
    }

    private static func appendUInt32(_ value: UInt32, to out: inout Data) {
        out.append(contentsOf: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) })
    }

    private static func padToFour(_ out: inout Data) {
        while out.count % 4 != 0 { out.append(0) }
    }
}

private struct Reader {
    let bytes: [UInt8]
    var offset = 0

    var hasMore: Bool { offset < bytes.count }
    var peek: UInt8 { bytes[offset] }

    mutating func string() throws -> String {
        guard hasMore, let end = bytes[offset...].firstIndex(of: 0) else {
            throw OSCDecodeError.unterminatedString
        }
        let value = String(decoding: bytes[offset..<end], as: UTF8.self)
        offset = Swift.min(aligned(end + 1), bytes.count)
        return value
    }

    mutating func uint32() throws -> UInt32 {
        guard offset + 4 <= bytes.count else { throw OSCDecodeError.truncated }
        defer { offset += 4 }
        return bytes[offset..<offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
    }

    mutating func blob() throws -> Data {
        let length = Int(try uint32())
        guard offset + length <= bytes.count else { throw OSCDecodeError.truncated }
        defer { offset = Swift.min(aligned(offset + length), bytes.count) }
        return Data(bytes[offset..<offset + length])
    }

    private func aligned(_ value: Int) -> Int { (value + 3) & ~3 }
}

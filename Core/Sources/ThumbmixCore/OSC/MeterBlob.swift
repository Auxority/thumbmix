import Foundation

/// Meter blobs break the OSC rule: a little-endian Int32 count, then little-endian Float32 values
/// (Maillot protocol doc p.16).
public enum MeterBlob {
    public static func floats(from blob: Data) -> [Float] {
        let bytes = [UInt8](blob)
        guard bytes.count >= 4 else { return [] }
        let available = (bytes.count - 4) / 4
        let count = Swift.min(Int(littleEndian(bytes, at: 0)), available)
        return (0..<count).map { Float(bitPattern: littleEndian(bytes, at: 4 + $0 * 4)) }
    }

    public static func encode(_ values: [Float]) -> Data {
        var out = Data(littleEndianBytes(UInt32(values.count)))
        for value in values { out.append(contentsOf: littleEndianBytes(value.bitPattern)) }
        return out
    }

    private static func littleEndian(_ bytes: [UInt8], at index: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 | UInt32(bytes[index + $1]) << ($1 * 8) }
    }

    private static func littleEndianBytes(_ value: UInt32) -> [UInt8] {
        (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
    }
}

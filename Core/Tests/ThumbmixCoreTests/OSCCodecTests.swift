import Foundation
import Testing
@testable import ThumbmixCore

struct OSCCodecTests {
    @Test func encodesFloatMessageExactly() {
        var expected = Data("/ch/01/mix/fader".utf8) + Data(repeating: 0, count: 4)
        expected += Data(",f".utf8) + Data(repeating: 0, count: 2)
        expected += Data([0x3F, 0x40, 0x00, 0x00])

        #expect(OSCCodec.encode(OSCMessage("/ch/01/mix/fader", [.float(0.75)])) == expected)
    }

    @Test func requestWithoutArgumentsHasNoTypeTag() {
        #expect(OSCCodec.encode(OSCMessage("/xremote")) == Data("/xremote".utf8) + Data(repeating: 0, count: 4))
    }

    @Test func roundTripsEveryType() throws {
        let message = OSCMessage("/x", [.int(-7), .float(0.25), .string("Kick Drum"), .blob(Data([1, 2, 3]))])
        #expect(try OSCCodec.decode(OSCCodec.encode(message)) == message)
    }

    @Test func decodesMessageWithoutTypeTag() throws {
        let decoded = try OSCCodec.decode(Data("/xremote".utf8) + Data(repeating: 0, count: 4))
        #expect(decoded == OSCMessage("/xremote"))
    }

    @Test func decodesNodeReplyWithoutLeadingSlash() throws {
        let reply = OSCMessage("node", [.string("/ch/01/mix ON -oo OFF +0 OFF -oo\n")])
        #expect(try OSCCodec.decode(OSCCodec.encode(reply)) == reply)
    }

    @Test func truncatedThrows() {
        var data = OSCCodec.encode(OSCMessage("/ch/01/mix/fader", [.float(0.75)]))
        data.removeLast(2)
        #expect(throws: OSCDecodeError.truncated) { try OSCCodec.decode(data) }
    }

    @Test func unknownTypeTagThrows() {
        let data = Data("/x".utf8) + Data([0, 0]) + Data(",T".utf8) + Data([0, 0])
        #expect(throws: OSCDecodeError.unsupportedType("T")) { try OSCCodec.decode(data) }
    }

    @Test func meterBlobIsLittleEndianCountThenFloats() {
        let blob = Data([2, 0, 0, 0, 0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x3F])
        #expect(MeterBlob.floats(from: blob) == [1.0, 0.5])
        #expect(MeterBlob.encode([1.0, 0.5]) == blob)
    }

    @Test func shortMeterBlobYieldsWhatIsThere() {
        #expect(MeterBlob.floats(from: Data([5, 0, 0, 0, 0x00, 0x00, 0x80, 0x3F])) == [1.0])
        #expect(MeterBlob.floats(from: Data([1, 0])) == [])
    }
}

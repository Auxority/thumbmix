import Testing

@testable import ThumbmixCore

/// Every label that names a strip shows a linked pair as one name and a lone strip by its own.
@MainActor
struct DisplayNameTests {
    private let mirror = ConsoleMirror(link: ConsoleLink(host: "127.0.0.1", port: 9))

    @Test func linkedPairShowsTheSharedName() {
        mirror.apply(OSCMessage("/config/chlink/9-10", [.int(1)]))
        mirror.apply(OSCMessage("/ch/09/config/name", [.string("Gtr L")]))
        mirror.apply(OSCMessage("/ch/10/config/name", [.string("Gtr R")]))
        #expect(mirror.displayName(StripID(.input, 10)) == "Gtr")
    }

    @Test func unlinkedStripShowsItsOwnName() {
        mirror.apply(OSCMessage("/config/chlink/9-10", [.int(0)]))
        mirror.apply(OSCMessage("/ch/09/config/name", [.string("Gtr L")]))
        mirror.apply(OSCMessage("/ch/10/config/name", [.string("Gtr R")]))
        #expect(mirror.displayName(StripID(.input, 10)) == "Gtr R")
    }

    @Test func linkedPairWithoutNamesFallsBackToTheRange() {
        mirror.apply(OSCMessage("/config/chlink/31-32", [.int(1)]))
        #expect(mirror.displayName(StripID(.input, 31)) == "Ch 31-32")
    }
}

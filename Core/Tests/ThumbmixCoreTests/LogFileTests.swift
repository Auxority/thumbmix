import Foundation
import OSLog
import Testing

@testable import ThumbmixCore

struct LogFileTests {
    /// What a reporter attaches to a GitHub issue: this run's Thumbmix lines under a line naming app and phone.
    @Test func holdsThisRunsThumbmixLines() async throws {
        let marker = UUID().uuidString
        Logger(subsystem: "thumbmix", category: "test").notice("marker \(marker, privacy: .public)")
        Logger(subsystem: "elsewhere", category: "test").notice("other \(marker, privacy: .public)")

        // The log store may take a moment to hand back a line just written.
        var text = ""
        let arrived = await eventually {
            text = (try? LogFile.text(header: "Thumbmix 1.2.3")) ?? ""
            return text.contains(marker)
        }
        #expect(arrived)
        #expect(text.hasPrefix("Thumbmix 1.2.3\n"))
        #expect(text.contains("[test] notice marker \(marker)"))
        #expect(!text.contains("other \(marker)"), "another subsystem's lines stay out")
    }
}

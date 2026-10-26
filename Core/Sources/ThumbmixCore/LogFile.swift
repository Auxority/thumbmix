import Foundation
import OSLog

/// This run's log as text, for a reporter to attach to a GitHub issue. iOS lets an app read back only its own
/// current run, so the app keeps no log file of its own: the reporter shares right after the problem.
public enum LogFile {
    /// Slow (seconds on a phone): call it off the main thread.
    public static func text(header: String) throws -> String {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let lines = try store.getEntries(matching: NSPredicate(format: "subsystem == 'thumbmix'"))
            .compactMap { $0 as? OSLogEntryLog }
            .map { "\($0.date.formatted(.iso8601)) [\($0.category)] \(name(of: $0.level)) \($0.composedMessage)" }
        return ([header, ""] + lines).joined(separator: "\n") + "\n"
    }

    private static func name(of level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        default: "?"
        }
    }
}

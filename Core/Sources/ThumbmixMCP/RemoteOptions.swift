import Foundation

/// The command line of `thumbmix-mcp`. Nothing starts on a mistake: it is named, with the usage.
public struct RemoteOptions: Equatable, Sendable {
    public enum Problem: Error, Equatable {
        case help
        case invalid(String)
    }

    public var host: String?
    public var consolePort: UInt16 = 10023
    /// Also serve MCP and the JSON API over HTTP on this port.
    public var httpPort: UInt16?
    /// Loopback: HTTP stays on this Mac unless `--bind` says otherwise.
    public var bindAddress = "127.0.0.1"
    /// Talk to an in-process fake desk, to try the tools without a console.
    public var fake = false

    public static let usage = """
        usage: thumbmix-mcp --host <M32 address> [--port 10023] [--http <port> [--bind <address>]]
               thumbmix-mcp --fake [--http <port> [--bind <address>]]

        Speaks MCP on stdin and stdout (newline-delimited JSON-RPC; logs go to stderr), so an AI client such as
        Claude Code can read and set the console.
          --host <address>  the console's IP address or name
          --port <port>     the console's OSC port (default 10023)
          --http <port>     also serve MCP at /mcp and a JSON API at /api/tools on this port
          --bind <address>  the address HTTP listens on (default 127.0.0.1; 0.0.0.0 is every interface)
          --fake            use a fake console in this process instead of --host
        """

    public static func parse(_ arguments: [String]) throws -> RemoteOptions {
        var options = RemoteOptions()
        var bind: String?
        var rest = arguments[...]
        while let flag = rest.popFirst() {
            switch flag {
            case "--help", "-h": throw Problem.help
            case "--fake": options.fake = true
            case "--host": options.host = try host(try value(of: flag, &rest))
            case "--port": options.consolePort = try port(of: flag, try value(of: flag, &rest))
            case "--http": options.httpPort = try port(of: flag, try value(of: flag, &rest))
            case "--bind": bind = try value(of: flag, &rest)
            default: throw Problem.invalid("Unknown option '\(flag.prefix(40))'.")
            }
        }
        if let bind {
            guard options.httpPort != nil else { throw Problem.invalid("--bind only applies together with --http.") }
            options.bindAddress = bind
        }
        try options.checkHost()
        return options
    }

    private func checkHost() throws {
        if fake && host != nil { throw Problem.invalid("--fake and --host can't be used together.") }
        if !fake && host == nil { throw Problem.invalid("--host is required (or --fake, to try it without a console).") }
    }

    private static func value(of flag: String, _ rest: inout ArraySlice<String>) throws -> String {
        guard let value = rest.first, !value.hasPrefix("--") else { throw Problem.invalid("\(flag) needs a value.") }
        rest.removeFirst()
        return value
    }

    private static func host(_ text: String) throws -> String {
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace || $0.isNewline }) else {
            throw Problem.invalid("--host needs an IP address or a name.")
        }
        return text
    }

    private static func port(of flag: String, _ text: String) throws -> UInt16 {
        guard let port = UInt16(text), port != 0 else {
            throw Problem.invalid("\(flag) needs a port number from 1 to 65535 (got '\(text.prefix(20))').")
        }
        return port
    }
}

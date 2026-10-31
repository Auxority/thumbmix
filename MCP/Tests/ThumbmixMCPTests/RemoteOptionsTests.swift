import Testing
import ThumbmixMCP

/// The command line of `thumbmix-mcp`: a mistake is named and nothing starts.
struct RemoteOptionsTests {
    private func problem(_ arguments: [String]) -> String? {
        do {
            _ = try RemoteOptions.parse(arguments)
            return nil
        } catch RemoteOptions.Problem.invalid(let message) {
            return message
        } catch RemoteOptions.Problem.help {
            return "help"
        } catch {
            return "other"
        }
    }

    @Test func aHostAloneUsesTheDefaults() throws {
        let options = try RemoteOptions.parse(["--host", "192.168.1.20"])

        #expect(options.host == "192.168.1.20")
        #expect(options.consolePort == 10023)
        #expect(options.httpPort == nil)
        #expect(options.bindAddress == "127.0.0.1", "HTTP, if asked for, stays on this Mac unless --bind says otherwise")
        #expect(!options.fake)
    }

    @Test func everyOptionIsRead() throws {
        let options = try RemoteOptions.parse(
            ["--host", "desk.local", "--port", "10024", "--http", "8032", "--bind", "0.0.0.0"])

        #expect(options.host == "desk.local")
        #expect(options.consolePort == 10024)
        #expect(options.httpPort == 8032)
        #expect(options.bindAddress == "0.0.0.0")
    }

    @Test func fakeNeedsNoHost() throws {
        let options = try RemoteOptions.parse(["--fake", "--http", "8032"])

        #expect(options.fake)
        #expect(options.host == nil)
    }

    @Test func aMissingHostIsNamed() {
        #expect(problem([])?.contains("--host") == true)
        #expect(problem(["--port", "10023"])?.contains("--host") == true)
    }

    @Test func conflictsAndStrayOptionsAreRefused() {
        #expect(problem(["--fake", "--host", "10.0.0.1"])?.contains("--fake") == true)
        #expect(problem(["--host", "10.0.0.1", "--bind", "0.0.0.0"])?.contains("--http") == true)
        #expect(problem(["--host", "10.0.0.1", "--verbose"])?.contains("--verbose") == true)
        #expect(problem(["--host", "10.0.0.1", "extra"])?.contains("extra") == true)
    }

    @Test func aPortThatIsNotAPortIsRefused() {
        for port in ["abc", "0", "65536", "-1", ""] {
            #expect(problem(["--host", "h", "--port", port])?.contains("--port") == true, "\(port)")
            #expect(problem(["--host", "h", "--http", port])?.contains("--http") == true, "\(port)")
        }
    }

    @Test func aValueThatIsMissingIsNamed() {
        #expect(problem(["--host"])?.contains("--host") == true)
        #expect(problem(["--host", "h", "--port"])?.contains("--port") == true)
        #expect(problem(["--host", ""])?.contains("--host") == true)
        #expect(problem(["--host", "a b"])?.contains("--host") == true)
    }

    @Test func helpShowsTheUsage() {
        #expect(problem(["--help"]) == "help")
        #expect(problem(["-h"]) == "help")
        #expect(RemoteOptions.usage.contains("thumbmix-mcp --host"))
    }
}

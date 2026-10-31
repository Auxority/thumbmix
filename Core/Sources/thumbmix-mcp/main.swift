import FakeM32
import Foundation
import ThumbmixCore
import ThumbmixMCP

// MCP on stdin and stdout for an AI client such as Claude Code. Stdout carries MCP and nothing else: every message
// for a person goes to stderr.
let version = "0.1.0"

func say(_ text: String) {
    FileHandle.standardError.write(Data("thumbmix-mcp: \(text)\n".utf8))
}

func describe(_ status: MirrorStatus, host: String) -> String {
    switch status {
    case .connecting: "connecting to \(host)"
    case .syncing: "connected, reading the desk"
    case .live: "live"
    case .lost: "contact with the desk is lost; reconnecting"
    case .failed: "no M32 answered at \(host); trying again every 5 s"
    }
}

let options: RemoteOptions
do {
    options = try RemoteOptions.parse(Array(CommandLine.arguments.dropFirst()))
} catch RemoteOptions.Problem.help {
    print(RemoteOptions.usage)
    exit(0)
} catch RemoteOptions.Problem.invalid(let message) {
    say(message)
    say(RemoteOptions.usage)
    exit(2)
}

// A client that goes away must end a write with an error, not kill the process.
signal(SIGPIPE, SIG_IGN)

var deskHost = options.host ?? "127.0.0.1"
var deskPort = options.consolePort
var fakeDesk: FakeM32?
if options.fake {
    let fake = try FakeM32(streamsMeters: false)
    deskPort = try await fake.start()
    fakeDesk = fake
    deskHost = "127.0.0.1"
    say("a fake desk is listening on 127.0.0.1:\(deskPort); nothing here touches a real console")
}

let host = deskHost
let port = deskPort
let makeMirror: @MainActor () -> ConsoleMirror = { ConsoleMirror(link: ConsoleLink(host: host, port: port)) }
let firstMirror = makeMirror()
firstMirror.start()

var configuration = RemoteConfiguration()
if let httpPort = options.httpPort {
    configuration.port = httpPort
    configuration.bindAddress = options.bindAddress
}
let remote = RemoteServer(mirror: firstMirror, configuration: configuration)
let reconnecting = Task { await remote.keepConnected(retryEvery: .seconds(5), makeMirror: makeMirror) }
let reporting = Task {
    var last = ""
    while !Task.isCancelled {
        let now = describe(remote.status, host: host)
        if now != last { say(now) }
        last = now
        try? await Task.sleep(for: .milliseconds(500))
    }
}

if options.httpPort != nil {
    let handler = try await MCPBridge.httpHandler(for: remote, version: version)
    let bound = try await remote.start(mcp: handler)
    say("HTTP on \(options.bindAddress):\(bound): MCP at /mcp, JSON API at /api/tools")
}
try await MCPBridge.serveStdio(remote, version: version)

reconnecting.cancel()
reporting.cancel()
remote.stop()
withExtendedLifetime(fakeDesk) {}

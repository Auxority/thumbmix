import FakeM32
import Foundation
import Testing
import ThumbmixMCP

@testable import ThumbmixCore

/// A client at the other end of the pipes `thumbmix-mcp` has as stdin and stdout.
@MainActor
final class StdioClient {
    struct Silence: Error {}

    private let toServer = Pipe()
    private let fromServer = Pipe()
    private var received: [String] = []
    private var reader: Task<Void, Never>?

    var serverInput: FileHandle { toServer.fileHandleForReading }
    var serverOutput: FileHandle { fromServer.fileHandleForWriting }

    init() {
        let lines = fromServer.fileHandleForReading.bytes.lines
        reader = Task { [weak self] in
            do {
                for try await line in lines { self?.received.append(line) }
            } catch {}
        }
    }

    func send(_ json: JSON) {
        sendLine(String(decoding: json.serialized() ?? Data(), as: UTF8.self))
    }

    func sendLine(_ text: String) {
        try? toServer.fileHandleForWriting.write(contentsOf: Data((text + "\n").utf8))
    }

    func rpc(_ id: Int, _ method: String, _ params: JSON? = nil) {
        var message: [String: JSON] = ["jsonrpc": "2.0", "id": .number(Double(id)), "method": .string(method)]
        if let params { message["params"] = params }
        send(.object(message))
    }

    /// The next line the server wrote, which must be one JSON message.
    func next() async throws -> JSON {
        guard await eventually(timeout: .seconds(10), { !received.isEmpty }) else { throw Silence() }
        return try JSON.parse(Data(received.removeFirst().utf8))
    }

    var unreadLines: Int { received.count }

    func closeInput() { try? toServer.fileHandleForWriting.close() }

    deinit { reader?.cancel() }
}

/// What the Mac tool does on its stdin and stdout, with the MCP SDK between: newline-delimited JSON-RPC, the tools of
/// `RemoteServer`, and nothing else on stdout.
@MainActor
struct RemoteStdioTests {
    private let bass = StripID(.input, 8)

    private func serve(_ mirror: ConsoleMirror) -> (StdioClient, Task<Void, Never>) {
        let client = StdioClient()
        let remote = RemoteServer(mirror: mirror)
        let serving = Task<Void, Never> {
            do {
                try await MCPBridge.serveStdio(remote, version: "test", input: client.serverInput, output: client.serverOutput)
            } catch {}
        }
        return (client, serving)
    }

    @Test func aClientCanInitializeAndListToolsOverThePipes() async throws {
        let (client, serving) = serve(idleMirror())
        do {
            client.rpc(
                1, "initialize", ["protocolVersion": "2025-11-25", "capabilities": [:], "clientInfo": ["name": "t", "version": "1"]])
            let initialize = try await client.next()
            #expect(initialize["id"] == 1)
            #expect(initialize["result"]?["protocolVersion"] == "2025-11-25")
            #expect(initialize["result"]?["serverInfo"]?["name"] == "thumbmix")
            #expect(initialize["result"]?["capabilities"]?["tools"] != nil)
            #expect(initialize["result"]?["instructions"]?.string?.contains("list_strips") == true)

            client.send(["jsonrpc": "2.0", "method": "notifications/initialized"])
            client.rpc(2, "tools/list")
            let list = try await client.next()
            #expect(list["id"] == 2, "a notification gets no answer, so the next line is the list")
            guard case .array(let tools)? = list["result"]?["tools"] else {
                Issue.record("no tools in \(list)")
                return
            }
            #expect(
                tools.compactMap { $0["name"]?.string } == ["list_strips", "get_strip", "set_fader", "set_mute", "set_eq_band", "set_comp"])
            let eq = tools.first { $0["name"] == "set_eq_band" }
            #expect(eq?["inputSchema"]?["properties"]?["gain_db"]?["maximum"] == 15)
            #expect(eq?["annotations"]?["readOnlyHint"] == false)
            client.closeInput()
            await serving.value
        }
    }

    @Test func aClientCanReadAndSetThroughTheToolsOverThePipes() async throws {
        try await withLiveDesk { fake, mirror in
            let (client, serving) = serve(mirror)

            client.rpc(3, "tools/call", ["name": "get_strip", "arguments": ["strip": "Bass"]])
            let get = try await client.next()
            #expect(get["id"] == 3)
            #expect(get["result"]?["structuredContent"]?["id"] == "ch/08")
            #expect(get["result"]?["structuredContent"]?["preamp"]?["gain_db"] != nil)
            #expect(get["result"]?["isError"] != true)

            client.rpc(4, "tools/call", ["name": "set_eq_band", "arguments": ["strip": "Bass", "band": 1, "gain_db": 3]])
            let set = try await client.next()
            #expect(set["result"]?["isError"] != true)
            let write = Catalog.deskArguments([(Catalog.eqBand(bass, 1).gain, 3)])[0]
            #expect(await eventually { fake.value(at: write.address) == write.argument })

            client.rpc(5, "tools/call", ["name": "set_eq_band", "arguments": ["strip": "Bass", "band": 1, "gain_db": 99]])
            let refused = try await client.next()
            #expect(refused["result"]?["isError"] == true)
            #expect(
                refused["result"]?["content"].flatMap { if case .array(let items) = $0 { items.first?["text"]?.string } else { nil } }?
                    .contains("not clamped") == true)

            client.closeInput()
            await serving.value
            #expect(client.unreadLines == 0, "nothing but the answers went to stdout")
        }
    }

    @Test func serveStdioReturnsWhenInputEnds() async throws {
        let (client, serving) = serve(idleMirror())
        var finished = false
        let waiting = Task {
            await serving.value
            finished = true
        }

        client.closeInput()

        #expect(await eventually(timeout: .seconds(5)) { finished })
        waiting.cancel()
    }

    @Test func aToolCallOnADeskThatIsNotLiveAnswersAtOnceInsteadOfWaiting() async throws {
        let (client, serving) = serve(idleMirror())

        client.rpc(1, "tools/call", ["name": "list_strips", "arguments": [:]])
        let reply = try await client.next()

        #expect(reply["result"]?["isError"] == true)
        let text = reply["result"]?["content"].flatMap { if case .array(let items) = $0 { items.first?["text"]?.string } else { nil } }
        #expect(text?.contains("connecting") == true)
        client.closeInput()
        await serving.value
    }

    @Test func anUnknownToolIsAProtocolError() async throws {
        let (client, serving) = serve(idleMirror())

        client.rpc(1, "tools/call", ["name": "launch_missiles", "arguments": [:]])
        let reply = try await client.next()

        #expect(reply["error"]?["code"] == -32602)
        #expect(reply["error"]?["message"]?.string?.contains("launch_missiles") == true)
        client.closeInput()
        await serving.value
    }

    @Test func aLineThatIsNotJSONGetsAnErrorAndTheLoopGoesOn() async throws {
        let (client, serving) = serve(idleMirror())

        client.sendLine("{nope")
        let parse = try await client.next()
        #expect(parse["error"]?["code"] == -32700)

        client.rpc(7, "ping")
        let ping = try await client.next()
        #expect(ping["id"] == 7)
        client.closeInput()
        await serving.value
    }

    @Test func aSlowToolDoesNotBlockTheNextRequest() async throws {
        try await withLiveDesk { _, mirror in
            let (client, serving) = serve(mirror)

            client.rpc(1, "tools/call", ["name": "get_strip", "arguments": ["strip": "Bass"]])
            client.rpc(2, "ping")
            let first = try await client.next()
            let second = try await client.next()

            #expect(Set([first["id"], second["id"]]) == [1, 2])
            client.closeInput()
            await serving.value
        }
    }
}

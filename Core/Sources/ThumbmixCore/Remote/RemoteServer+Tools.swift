import Foundation

/// A tool as a front end advertises it. Schemas travel as JSON bytes, so no front end needs this module's JSON type.
public struct RemoteToolInfo: Sendable {
    public let name: String
    public let description: String
    /// The JSON Schema of the arguments, as a JSON object.
    public let inputSchema: Data
    /// A read changes nothing on the desk.
    public let isReadOnly: Bool
}

/// What a tool did: the answer or the reason it refused. A refusal is a result the model reads and corrects, not a
/// protocol error.
public struct RemoteToolResult: Sendable {
    /// The same JSON as `structured`, or the refusal's words.
    public let text: String
    public let structured: Data?
    public let isError: Bool
}

/// The tools themselves, for any front end: `ThumbmixMCP` registers them with the MCP SDK, and `/api/tools` serves them
/// over plain HTTP. Arguments are checked here against each tool's own schema, whoever sends them.
extension RemoteServer {
    /// What a model reads first: how to use the tools safely.
    public nonisolated static let instructions = """
        These tools control a Midas M32 mixing console through Thumbmix. Values are real units: dB, Hz, ms. \
        Find the strip with list_strips, read it with get_strip, then change it with a set_ tool. For a relative \
        request ("more bass", "more compression") read the current value first and move from it in small steps \
        (about 1-3 dB of EQ gain), unless the user asks for more: a change is audible at once, maybe in a live show. \
        A value that is null was not read from the desk and is unknown. Writes while contact with the desk is lost \
        are refused.
        """

    public var toolInfos: [RemoteToolInfo] {
        tools.table.tools.map { tool in
            RemoteToolInfo(
                name: tool.name, description: tool.description,
                inputSchema: tool.definition["inputSchema"]?.serialized() ?? Data("{}".utf8), isReadOnly: tool.isReadOnly)
        }
    }

    /// Nil for a tool that doesn't exist. `arguments` is a JSON object (nil or empty: none).
    public func callTool(_ name: String, arguments: Data?) async -> RemoteToolResult? {
        let table = tools.table
        guard let tool = table.tool(named: name) else { return nil }
        let result: ToolResult
        do {
            result = await table.call(tool, arguments: try Self.object(arguments), requestID: RequestIDs.next())
        } catch let error as ToolError {
            result = .failure(error)
        } catch {
            result = .failure(.invalid("The arguments could not be read."))
        }
        switch result {
        case .success(let value):
            return RemoteToolResult(
                text: value.serialized().flatMap { String(data: $0, encoding: .utf8) } ?? "{}", structured: value.serialized(),
                isError: false)
        case .failure(let error):
            return RemoteToolResult(text: error.message, structured: nil, isError: true)
        }
    }

    private static func object(_ data: Data?) throws -> [String: JSON] {
        guard let data, !data.isEmpty else { return [:] }
        guard case .object(let fields)? = try? JSON.parse(data) else {
            throw ToolError.invalid("The arguments must be a JSON object.")
        }
        return fields
    }
}

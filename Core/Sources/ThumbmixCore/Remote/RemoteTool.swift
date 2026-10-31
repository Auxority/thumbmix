import Foundation
import os

/// Why a tool did not do what it was asked. The text goes to the AI client, so it says what to change.
struct ToolError: Error, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// The request is wrong: a name, a type, a number out of range.
        case invalid
        /// The request is fine but the desk can't take it now: contact lost, a value never read.
        case unavailable
    }

    let kind: Kind
    let message: String

    static func invalid(_ message: String) -> ToolError { ToolError(kind: .invalid, message: message) }
    static func unavailable(_ message: String) -> ToolError { ToolError(kind: .unavailable, message: message) }
}

/// One argument of a tool. The same list makes the tool's JSON schema and checks the arguments, so the two can't differ.
struct ToolParameter: Sendable {
    enum Kind: Sendable {
        case string
        case boolean
        /// Inclusive. A number outside is refused, never clamped.
        case number(ClosedRange<Double>)
        case integer(ClosedRange<Int>)
        case numberChoice([Double])
    }

    let name: String
    let description: String
    let kind: Kind
    var isRequired = false
}

/// A tool's arguments after the checks: every key is known, every value has the right type and lies in range.
struct ToolArguments {
    private let values: [String: JSON]

    init(_ raw: [String: JSON], for parameters: [ToolParameter]) throws {
        let known = Set(parameters.map(\.name))
        if let stray = raw.keys.sorted().first(where: { !known.contains($0) }) {
            let names = parameters.map(\.name).joined(separator: ", ")
            throw ToolError.invalid("Unknown argument '\(stray)'. This tool takes: \(names.isEmpty ? "no arguments" : names).")
        }
        for parameter in parameters {
            guard let value = raw[parameter.name], value != .null else {
                if parameter.isRequired { throw ToolError.invalid("'\(parameter.name)' is required.") }
                continue
            }
            try Self.check(value, against: parameter)
        }
        values = raw.filter { $0.value != .null }
    }

    func string(_ name: String) -> String? { values[name]?.string }
    func number(_ name: String) -> Double? { if case .number(let number)? = values[name] { number } else { nil } }
    func integer(_ name: String) -> Int? { number(name).map { Int($0) } }
    func bool(_ name: String) -> Bool? { if case .bool(let flag)? = values[name] { flag } else { nil } }

    private static func check(_ value: JSON, against parameter: ToolParameter) throws {
        let name = parameter.name
        switch (parameter.kind, value) {
        case (.string, .string(let text)):
            guard !text.isEmpty, text.count <= 100 else { throw ToolError.invalid("'\(name)' must be 1 to 100 characters.") }
        case (.boolean, .bool): return
        case (.number(let range), .number(let number)):
            try requireInside(number, range, name)
        case (.integer(let range), .number(let number)):
            guard number == number.rounded(), let whole = Int(exactly: number) else {
                throw ToolError.invalid("'\(name)' must be a whole number.")
            }
            try requireInside(Double(whole), Double(range.lowerBound)...Double(range.upperBound), name)
        case (.numberChoice(let choices), .number(let number)):
            guard choices.contains(number) else {
                throw ToolError.invalid("'\(name)' must be one of \(choices.map(format).joined(separator: ", ")) (got \(format(number))).")
            }
        default:
            throw ToolError.invalid("'\(name)' must be \(parameter.kind.typeName).")
        }
    }

    private static func requireInside(_ number: Double, _ range: ClosedRange<Double>, _ name: String) throws {
        guard range.contains(number) else {
            throw ToolError.invalid(
                "'\(name)' must be between \(format(range.lowerBound)) and \(format(range.upperBound)) (got \(format(number))). "
                    + "Values outside the range are refused, not clamped.")
        }
    }

    static func format(_ number: Double) -> String { String(format: "%g", number) }
}

extension ToolParameter.Kind {
    fileprivate var typeName: String {
        switch self {
        case .string: "a string"
        case .boolean: "true or false"
        case .number, .numberChoice: "a number"
        case .integer: "a whole number"
        }
    }

    fileprivate var schema: [String: JSON] {
        switch self {
        case .string: ["type": "string"]
        case .boolean: ["type": "boolean"]
        case .number(let range): ["type": "number", "minimum": .number(range.lowerBound), "maximum": .number(range.upperBound)]
        case .integer(let range):
            ["type": "integer", "minimum": .number(Double(range.lowerBound)), "maximum": .number(Double(range.upperBound))]
        case .numberChoice(let choices): ["type": "number", "enum": .array(choices.map(JSON.number))]
        }
    }
}

/// The outcome of a tool run, whichever front end asked.
enum ToolResult {
    case success(JSON)
    case failure(ToolError)

    /// MCP's `tools/call` result, also what the JSON API answers. A refusal is a result with `isError`, not a
    /// protocol error: the model reads it and corrects itself.
    var json: JSON {
        switch self {
        case .success(let value):
            .object([
                "content": [
                    .object(["type": "text", "text": .string(value.serialized().flatMap { String(data: $0, encoding: .utf8) } ?? "{}")])
                ], "structuredContent": value, "isError": false,
            ])
        case .failure(let error):
            ["content": [["type": "text", "text": .string(error.message)]], "isError": true]
        }
    }

    var httpStatus: Int {
        switch self {
        case .success: 200
        case .failure(let error): error.kind == .invalid ? 422 : 503
        }
    }
}

struct RemoteTool: Sendable {
    let name: String
    let description: String
    let parameters: [ToolParameter]
    /// A read changes nothing on the desk; clients may call it freely.
    let isReadOnly: Bool
    let run: @MainActor @Sendable (ToolArguments) async throws -> JSON

    /// As MCP's `tools/list` shows it.
    var definition: JSON {
        var properties: [String: JSON] = [:]
        for parameter in parameters {
            properties[parameter.name] = .object(parameter.kind.schema.merging(["description": .string(parameter.description)]) { $1 })
        }
        let required = parameters.filter(\.isRequired).map { JSON.string($0.name) }
        return [
            "name": .string(name), "description": .string(description),
            "inputSchema": [
                "type": "object", "properties": .object(properties), "required": .array(required), "additionalProperties": false,
            ],
            "annotations": [
                "readOnlyHint": .bool(isReadOnly), "destructiveHint": false, "idempotentHint": .bool(isReadOnly), "openWorldHint": false,
            ],
        ]
    }
}

/// The one list of tools both front ends use: MCP's `tools/call` and the JSON API's `POST /api/tools/<name>`.
struct ToolTable: Sendable {
    let tools: [RemoteTool]

    func tool(named name: String) -> RemoteTool? { tools.first { $0.name == name } }

    var listJSON: JSON { .array(tools.map(\.definition)) }

    private static let log = Logger(subsystem: "thumbmix", category: "mcp")

    /// Logs the tool and how it ended, never its arguments or the desk's values.
    func call(_ tool: RemoteTool, arguments: [String: JSON], requestID: Int) async -> ToolResult {
        let result: ToolResult
        do {
            let checked = try ToolArguments(arguments, for: tool.parameters)
            result = .success(try await tool.run(checked))
        } catch let error as ToolError {
            result = .failure(error)
        } catch {
            result = .failure(.unavailable("The tool failed unexpectedly."))
        }
        switch result {
        case .success: Self.log.info("[\(requestID)] tool \(tool.name, privacy: .public) ok")
        case .failure(let error):
            Self.log.info("[\(requestID)] tool \(tool.name, privacy: .public) refused: \(error.message, privacy: .public)")
        }
        return result
    }
}

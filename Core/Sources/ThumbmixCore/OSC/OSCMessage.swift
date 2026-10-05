import Foundation

public enum OSCArgument: Equatable, Sendable {
    case int(Int32)
    case float(Float)
    case string(String)
    case blob(Data)

    var typeTag: String {
        switch self {
        case .int: "i"
        case .float: "f"
        case .string: "s"
        case .blob: "b"
        }
    }
}

public struct OSCMessage: Equatable, Sendable {
    public var address: String
    public var arguments: [OSCArgument]

    public init(_ address: String, _ arguments: [OSCArgument] = []) {
        self.address = address
        self.arguments = arguments
    }

    public func string(at index: Int) -> String? {
        guard arguments.indices.contains(index), case let .string(value) = arguments[index] else { return nil }
        return value
    }
}

import Foundation

/// One HTTP request as the server reads it; `ThumbmixMCP` hands `POST /mcp` to the MCP SDK from this.
public struct RemoteRequest: Equatable, Sendable {
    public let method: String
    /// Without the query: no endpoint reads one.
    public let path: String
    /// Names in lower case.
    public let headers: [String: String]
    public let body: Data
}

enum HTTPParse: Equatable {
    case needMore
    case request(RemoteRequest)
    case refuse(status: Int, reason: String)
}

/// Reads one HTTP/1.1 request from what has arrived so far. The bytes come from the network, so every limit is checked
/// as soon as the part it limits is known. One request per connection: bytes after the body are dropped.
enum HTTPRequestParser {
    static let maxHeaderBytes = 16 * 1024
    private static let maxTargetLength = 2048
    private static let headerEnd = Data("\r\n\r\n".utf8)

    static func parse(_ data: Data, maxBody: Int) -> HTTPParse {
        guard let end = data.range(of: headerEnd) else {
            return data.count > maxHeaderBytes ? refusal(431, "The request headers are too large.") : .needMore
        }
        do {
            guard end.lowerBound <= maxHeaderBytes else { throw Refusal(431, "The request headers are too large.") }
            guard let head = String(data: data[..<end.lowerBound], encoding: .utf8) else {
                throw Refusal(400, "The request headers are not UTF-8.")
            }
            var lines = head.components(separatedBy: "\r\n")
            let (method, path) = try requestLine(lines.removeFirst())
            let headers = try headerFields(lines)
            let length = try bodyLength(headers, maxBody: maxBody)
            let bodyStart = end.upperBound
            guard data.count - bodyStart >= length else { return .needMore }
            let body = data[bodyStart..<(bodyStart + length)]
            return .request(RemoteRequest(method: method, path: path, headers: headers, body: Data(body)))
        } catch let refusal as Refusal {
            return .refuse(status: refusal.status, reason: refusal.reason)
        } catch {
            return refusal(400, "The request could not be read.")
        }
    }

    private struct Refusal: Error {
        let status: Int
        let reason: String
        init(_ status: Int, _ reason: String) {
            self.status = status
            self.reason = reason
        }
    }

    private static func refusal(_ status: Int, _ reason: String) -> HTTPParse {
        .refuse(status: status, reason: reason)
    }

    private static func requestLine(_ line: String) throws -> (method: String, path: String) {
        let parts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[2].hasPrefix("HTTP/1."), !parts[0].isEmpty,
            parts[0].allSatisfy({ $0.isASCII && $0.isUppercase })
        else { throw Refusal(400, "The request line is malformed.") }
        let target = String(parts[1])
        guard target.hasPrefix("/"), !target.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
        else { throw Refusal(400, "The request target must be a path.") }
        guard target.count <= maxTargetLength else { throw Refusal(414, "The request target is too long.") }
        return (String(parts[0]), String(target.prefix { $0 != "?" }))
    }

    private static func headerFields(_ lines: [String]) throws -> [String: String] {
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":"), colon != line.startIndex, !line.hasPrefix(" "), !line.hasPrefix("\t")
            else { throw Refusal(400, "A header line is malformed.") }
            let name = line[..<colon].lowercased()
            guard !name.contains(" ") else { throw Refusal(400, "A header name has a space in it.") }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if let known = headers[name] {
                // Two lengths that differ is how request smuggling starts.
                guard name != "content-length" || known == value else { throw Refusal(400, "Content-Length is given twice.") }
                headers[name] = name == "content-length" ? value : known + ", " + value
            } else {
                headers[name] = value
            }
        }
        return headers
    }

    private static func bodyLength(_ headers: [String: String], maxBody: Int) throws -> Int {
        guard headers["transfer-encoding"] == nil else {
            throw Refusal(501, "Chunked request bodies are not supported; send a Content-Length.")
        }
        guard let text = headers["content-length"] else { return 0 }
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }), let length = Int(text) else {
            throw Refusal(400, "Content-Length is not a number.")
        }
        guard length <= maxBody else { throw Refusal(413, "The request body is larger than \(maxBody) bytes.") }
        return length
    }
}

public struct RemoteResponse: Sendable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    init(status: Int, json: JSON, headers: [String: String] = [:]) {
        self.init(
            status: status, headers: headers.merging(["Content-Type": "application/json"]) { _, new in new },
            body: json.serialized() ?? Data("{}".utf8))
    }

    /// Always closes the connection afterwards: one request per connection keeps the server free of connection state.
    func serialized() -> Data {
        var lines = ["HTTP/1.1 \(status) \(Self.reason(status))"]
        let fixed = ["Content-Length": "\(body.count)", "Connection": "close", "Cache-Control": "no-store"]
        for (name, value) in headers.merging(fixed, uniquingKeysWith: { _, new in new }).sorted(by: { $0.key < $1.key }) {
            lines.append("\(name): \(value)")
        }
        return Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8) + body
    }

    private static func reason(_ status: Int) -> String {
        switch status {
        case 200: "OK"
        case 202: "Accepted"
        case 400: "Bad Request"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 406: "Not Acceptable"
        case 413: "Content Too Large"
        case 414: "URI Too Long"
        case 415: "Unsupported Media Type"
        case 422: "Unprocessable Content"
        case 431: "Request Header Fields Too Large"
        case 501: "Not Implemented"
        case 503: "Service Unavailable"
        default: "Error"
        }
    }
}

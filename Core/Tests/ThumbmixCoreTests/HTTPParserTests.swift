import Foundation
import Testing

@testable import ThumbmixCore

/// The remote API reads bytes from the network: the parser decides what is a request and what is refused.
struct HTTPParserTests {
    private func parse(_ text: String, maxBody: Int = 1000) -> HTTPParse {
        HTTPRequestParser.parse(Data(text.utf8), maxBody: maxBody)
    }

    private func expectRefused(_ parsed: HTTPParse, _ status: Int) {
        guard case .refuse(let got, _) = parsed else {
            Issue.record("expected a refusal, got \(parsed)")
            return
        }
        #expect(got == status)
    }

    @Test func aPostWithABodyIsARequest() {
        let parsed = parse("POST /mcp?x=1 HTTP/1.1\r\nHost: a\r\nContent-Length: 5\r\nOrigin: http://x\r\n\r\nhello")

        guard case .request(let request) = parsed else {
            Issue.record("expected a request, got \(parsed)")
            return
        }
        #expect(request.method == "POST")
        #expect(request.path == "/mcp")
        #expect(request.headers["origin"] == "http://x")
        #expect(request.headers["content-length"] == "5")
        #expect(request.body == Data("hello".utf8))
    }

    @Test func aGetNeedsNoBody() {
        guard case .request(let request) = parse("GET /api/tools HTTP/1.1\r\nHost: a\r\n\r\n") else {
            Issue.record("expected a request")
            return
        }
        #expect(request.body.isEmpty)
    }

    @Test func waitsForTheRestOfTheHeadersAndTheBody() {
        #expect(parse("POST /mcp HTTP/1.1\r\nContent-Le") == .needMore)
        #expect(parse("POST /mcp HTTP/1.1\r\nContent-Length: 5\r\n\r\nhel") == .needMore)
    }

    @Test func aBodyOverTheLimitIsRefusedBeforeItArrives() {
        expectRefused(parse("POST /mcp HTTP/1.1\r\nContent-Length: 1001\r\n\r\n"), 413)
    }

    @Test func headersWithoutAnEndAreRefusedOnceTheyAreTooLong() {
        let long = "GET / HTTP/1.1\r\nX: " + String(repeating: "a", count: 20_000)
        expectRefused(parse(long), 431)
    }

    @Test func badRequestsAreRefused() {
        expectRefused(parse("NONSENSE\r\n\r\n"), 400)
        expectRefused(parse("GET /x HTTP/1.1\r\nno colon here\r\n\r\n"), 400)
        expectRefused(parse("POST /x HTTP/1.1\r\nContent-Length: -1\r\n\r\n"), 400)
        expectRefused(parse("POST /x HTTP/1.1\r\nContent-Length: abc\r\n\r\n"), 400)
        expectRefused(parse("POST /x HTTP/1.1\r\nContent-Length: 1\r\nContent-Length: 2\r\n\r\nab"), 400)
        expectRefused(parse("GET x HTTP/1.1\r\n\r\n"), 400)
    }

    @Test func chunkedBodiesAreNotSupported() {
        expectRefused(parse("POST /x HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n"), 501)
    }

    @Test func bytesAfterTheBodyAreIgnored() {
        guard case .request(let request) = parse("POST /x HTTP/1.1\r\nContent-Length: 2\r\n\r\nabGET /y") else {
            Issue.record("expected a request")
            return
        }
        #expect(request.body == Data("ab".utf8))
    }
}

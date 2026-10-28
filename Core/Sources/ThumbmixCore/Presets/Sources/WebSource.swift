import Foundation

enum SourceError: Error, Equatable {
    case refusedAddress
    case unreachable(String)
    case notASource
    case tooLarge
    case notText
    case badPath(String)
    case tooMany

    var message: String {
        switch self {
        case .refusedAddress: CoreStrings.text("The address must be https:// with no name, password or query.")
        case .unreachable(let why): CoreStrings.text("Couldn't read it: \(why)")
        case .notASource: CoreStrings.text("This is not a Thumbmix source.")
        case .tooLarge: CoreStrings.text("The file is too large.")
        case .notText: CoreStrings.text("The answer is not UTF-8 JSON text.")
        case .badPath(let path): CoreStrings.text("The path \(path) leaves the source.")
        case .tooMany: CoreStrings.text("The source lists more than 200 presets.")
        }
    }
}

/// The index a web source serves: `"format": "thumbmix-source"`, `"version": 1`, a name, and preset files by path,
/// relative to the index. Nothing else is followed: no other host, no way up, no query.
struct PresetIndex: Decodable {
    struct Entry: Decodable { let path: String }

    static let maxBytes = 64 * 1024

    let format: String
    let version: Int
    let name: String
    let presets: [Entry]

    func paths() throws -> [String] {
        guard format == "thumbmix-source", version == 1, !name.isEmpty, name.count <= PresetValidation.maxNameLength
        else { throw SourceError.notASource }
        guard presets.count <= SourceReader.maxPresets else { throw SourceError.tooMany }
        return presets.map(\.path)
    }
}

/// Lets a redirect through only to HTTPS without a name or password, and remembers one it stopped.
private final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false

    var didStopRedirect: Bool { lock.withLock { stopped } }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if let url = request.url, SourceReader.isAcceptable(url) {
            completionHandler(request)
        } else {
            lock.withLock { stopped = true }
            completionHandler(nil)
        }
    }
}

extension SourceReader {
    /// HTTPS, a host, no user or password, no query or fragment: nothing secret travels in a source address.
    static func isAcceptable(_ url: URL) -> Bool {
        url.scheme == "https" && url.host?.isEmpty == false && url.user == nil && url.password == nil
            && url.query == nil && url.fragment == nil
    }

    /// Reads the index and every preset it lists. A bad index, or an address that can't be read, keeps the last good
    /// read (`cache`); a bad preset is skipped and named.
    func readWeb(_ address: URL, cache: URL) async -> SourceResult {
        do {
            let (result, files) = try await fetchSource(address)
            writeCache(files, to: cache)
            return result
        } catch {
            return fromCache(cache, because: Self.reason(error))
        }
    }

    private func fetchSource(_ address: URL) async throws -> (SourceResult, [CachedFile]) {
        guard Self.isAcceptable(address) else { throw SourceError.refusedAddress }
        let indexData = try await fetch(address, limit: PresetIndex.maxBytes)
        guard let index = try? JSONDecoder().decode(PresetIndex.self, from: indexData) else { throw SourceError.notASource }
        let paths = try index.paths()
        let urls = try paths.map { try Self.resolve($0, against: address) }
        let fetched = await fetchAll(urls)
        var result = SourceResult(title: index.name)
        var files: [CachedFile] = []
        for (path, outcome) in zip(paths, fetched) {
            do {
                let data = try outcome.get()
                result.presets.append(SourcedPreset(preset: try PresetValidation.decode(data), file: path))
                files.append(CachedFile(file: path, data: data))
            } catch {
                result.skipped.append(SkippedFile(file: path, reason: Self.reason(error)))
            }
        }
        return (result, files)
    }

    private func fetchAll(_ urls: [URL]) async -> [Result<Data, Error>] {
        await withTaskGroup(of: (Int, Result<Data, Error>).self) { group in
            for (position, url) in urls.enumerated() {
                group.addTask { (position, await Result { try await fetch(url, limit: PresetValidation.maxBytes) }) }
            }
            var outcomes = [Result<Data, Error>](repeating: .failure(SourceError.notASource), count: urls.count)
            for await (position, outcome) in group { outcomes[position] = outcome }
            return outcomes
        }
    }

    /// A relative path of plain names. Anything that could point elsewhere is refused whole, not cleaned.
    static func resolve(_ path: String, against index: URL) throws -> URL {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        let isPlain =
            !path.isEmpty && path.count <= 100 && !path.hasPrefix("/")
            && parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
            && !path.contains { "\\?#:%".contains($0) || $0.unicodeScalars.contains { $0.properties.generalCategory == .control } }
        guard isPlain, let target = URL(string: path, relativeTo: index)?.absoluteURL, isAcceptable(target),
            target.host == index.host, target.port == index.port
        else { throw SourceError.badPath(path) }
        return target
    }

    /// At most `limit` bytes of a 200 answer that is text, as UTF-8, with no redirect to anything but HTTPS.
    private func fetch(_ url: URL, limit: Int) async throws -> Data {
        let (bytes, http) = try await request(url)
        guard http.statusCode == 200 else {
            throw SourceError.unreachable(CoreStrings.text("the server did not answer with the file"))
        }
        guard ["application/json", "text/plain"].contains(http.mimeType) else { throw SourceError.notText }
        guard http.expectedContentLength <= limit else { throw SourceError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > limit { throw SourceError.tooLarge }
        }
        guard String(data: data, encoding: .utf8) != nil else { throw SourceError.notText }
        return data
    }

    private func request(_ url: URL) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpShouldHandleCookies = false
        let redirects = RedirectGuard()
        let answer: (URLSession.AsyncBytes, URLResponse)
        do {
            answer = try await session.bytes(for: request, delegate: redirects)
        } catch {
            throw redirects.didStopRedirect ? SourceError.refusedAddress : SourceError.unreachable(error.localizedDescription)
        }
        guard !redirects.didStopRedirect else { throw SourceError.refusedAddress }
        guard let http = answer.1 as? HTTPURLResponse else { throw SourceError.notText }
        return (answer.0, http)
    }

    // MARK: Cache

    struct CachedFile: Codable {
        let file: String
        let data: Data
    }

    private struct Cache: Codable { let files: [CachedFile] }

    private func writeCache(_ files: [CachedFile], to cache: URL) {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(Cache(files: files)).write(to: cache, options: .atomic)
    }

    /// Checked again like a new file: the cache is the app's own copy, but a damaged one is not trusted either.
    private func fromCache(_ cache: URL, because reason: String) -> SourceResult {
        guard let data = try? Data(contentsOf: cache), let saved = try? JSONDecoder().decode(Cache.self, from: data) else {
            return .failed(reason)
        }
        let presets = saved.files.compactMap { file in
            (try? PresetValidation.decode(file.data)).map { SourcedPreset(preset: $0, file: file.file) }
        }
        return presets.isEmpty ? .failed(reason) : SourceResult(presets: presets, status: .cached(reason))
    }
}

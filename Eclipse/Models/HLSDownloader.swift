import Foundation
import CommonCrypto
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

struct HLSByteRange: Equatable {
    let offset: Int64
    let length: Int64

    var upperBound: Int64? {
        guard offset >= 0, length > 0 else { return nil }
        let (end, overflow) = offset.addingReportingOverflow(length - 1)
        return overflow ? nil : end
    }

    var headerValue: String? {
        guard let upperBound else { return nil }
        return "bytes=\(offset)-\(upperBound)"
    }

    static func parse(_ value: String, implicitOffset: Int64? = nil) -> HLSByteRange? {
        let parts = value.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2,
              let length = Int64(parts[0]), length > 0 else { return nil }
        let offset: Int64
        if parts.count == 2 {
            guard let parsedOffset = Int64(parts[1]), parsedOffset >= 0 else { return nil }
            offset = parsedOffset
        } else {
            guard let implicitOffset, implicitOffset >= 0 else { return nil }
            offset = implicitOffset
        }
        let range = HLSByteRange(offset: offset, length: length)
        return range.upperBound == nil ? nil : range
    }
}

struct HLSMediaResource: Equatable {
    let url: URL
    let byteRange: HLSByteRange?

    init(url: URL, byteRange: HLSByteRange? = nil) {
        self.url = url
        self.byteRange = byteRange
    }

    func apply(to request: inout URLRequest) {
        if let header = byteRange?.headerValue {
            request.setValue(header, forHTTPHeaderField: "Range")
        }
    }
}

struct HLSVariant {
    let url: URL
    let bandwidth: Int
    let resolution: String?
    let requiresExternalAudio: Bool

    init(url: URL, bandwidth: Int, resolution: String?, requiresExternalAudio: Bool = false) {
        self.url = url
        self.bandwidth = bandwidth
        self.resolution = resolution
        self.requiresExternalAudio = requiresExternalAudio
    }
}

enum HLSDownloadCompatibility {
    static let separateAudioMessage = "This HLS stream uses a separate audio playlist that cannot be packaged for offline playback. Choose another stream."

    static func attributes(_ value: String) -> [String: String] {
        var fields: [String] = []
        var field = ""
        var quoted = false
        for character in value {
            if character == "\"" { quoted.toggle() }
            if character == ",", !quoted {
                fields.append(field)
                field = ""
            } else {
                field.append(character)
            }
        }
        fields.append(field)
        var result: [String: String] = [:]
        for field in fields {
            let parts = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if value.count >= 2, value.first == "\"", value.last == "\"" {
                value.removeFirst()
                value.removeLast()
            }
            result[key] = value
        }
        return result
    }

    static func muxedAudioGroups(in playlist: String) -> [String: Bool] {
        var groups: [String: Bool] = [:]
        for line in playlist.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("#EXT-X-MEDIA:") else { continue }
            let values = attributes(String(line.dropFirst("#EXT-X-MEDIA:".count)))
            guard values["TYPE"] == "AUDIO", let group = values["GROUP-ID"] else { continue }
            groups[group] = (groups[group] ?? false) || values["URI"] == nil
        }
        return groups
    }

    static func requiresExternalAudio(attributes: [String: String], groups: [String: Bool]) -> Bool {
        guard let group = attributes["AUDIO"] else { return false }
        return groups[group] != true
    }

    static func mediaSequenceNumber(in playlist: String) -> UInt64? {
        let prefix = "#EXT-X-MEDIA-SEQUENCE:"
        let declarations = playlist.components(separatedBy: .newlines).compactMap { line -> String? in
            let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix(prefix) else { return nil }
            return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard declarations.count <= 1 else { return nil }
        guard let declaration = declarations.first else { return 0 }
        return UInt64(declaration)
    }

    static func sequenceNumber(base: UInt64, segmentIndex: Int) -> UInt64? {
        guard segmentIndex >= 0 else { return nil }
        let (sequence, overflow) = base.addingReportingOverflow(UInt64(segmentIndex))
        return overflow ? nil : sequence
    }

    static func defaultAES128IV(sequenceNumber: UInt64) -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        var value = sequenceNumber
        for index in stride(from: 15, through: 8, by: -1) {
            bytes[index] = UInt8(value & 0xff)
            value >>= 8
        }
        return Data(bytes)
    }

    static func isValidAES128KeyURL(_ value: String, relativeTo baseURL: URL) -> Bool {
        guard let url = URL(string: value, relativeTo: baseURL)?.absoluteURL,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil else { return false }
        let sourceScheme = baseURL.scheme?.lowercased()
        return !(sourceScheme == "https" && scheme == "http")
    }

    static func permitsRedirect(from source: URL, to destination: URL) -> Bool {
        guard let sourceScheme = source.scheme?.lowercased(),
              sourceScheme == "http" || sourceScheme == "https",
              let destinationScheme = destination.scheme?.lowercased(),
              destinationScheme == "http" || destinationScheme == "https",
              destination.host != nil,
              destination.user == nil,
              destination.password == nil else { return false }
        return !(sourceScheme == "https" && destinationScheme == "http")
    }

    static func isValidAES128IV(_ value: String) -> Bool {
        let digits = value.hasPrefix("0x") || value.hasPrefix("0X")
            ? String(value.dropFirst(2))
            : value
        return digits.count == 32 && digits.allSatisfy(\.isHexDigit)
    }

    static func unsupportedEncryptionLayout(in playlist: String) -> String? {
        var activeKeySignature: String?
        var hasSeenActiveKey = false

        for line in playlist.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("#EXT-X-KEY:") else { continue }
            let values = attributes(String(line.dropFirst("#EXT-X-KEY:".count)))
            guard let rawMethod = values["METHOD"], !rawMethod.isEmpty else {
                return "This HLS stream has an invalid encryption declaration and cannot be packaged safely for offline playback. Choose another stream."
            }
            let method = rawMethod.uppercased()

            if method == "NONE" {
                // The downloader currently uses one key for the whole media
                // playlist. A later key reset would leave earlier segments
                // encrypted because it cannot map keys to individual segments.
                if hasSeenActiveKey {
                    return "This HLS stream changes encryption keys within the playlist, which cannot be packaged safely for offline playback. Choose another stream."
                }
                continue
            }

            guard method == "AES-128",
                  values["URI"]?.isEmpty == false,
                  values["KEYFORMAT"]?.lowercased() == nil
                    || values["KEYFORMAT"]?.lowercased() == "identity" else {
                return "This HLS stream uses an encryption method that cannot be packaged safely for offline playback. Choose another stream."
            }

            let signature = [
                method,
                values["URI"] ?? "",
                values["IV"] ?? "",
                values["KEYFORMAT"]?.lowercased() ?? "identity"
            ].joined(separator: "|")
            if let activeKeySignature, activeKeySignature != signature {
                return "This HLS stream rotates encryption keys, which cannot be packaged safely for offline playback. Choose another stream."
            }
            activeKeySignature = signature
            hasSeenActiveKey = true
        }
        return nil
    }

    static func unsupportedMediaLayout(in playlist: String) -> String? {
        var initializationURI: String?
        for line in playlist.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("#EXT-X-MAP:") {
                let values = attributes(String(line.dropFirst("#EXT-X-MAP:".count)))
                if let range = values["BYTERANGE"],
                   HLSByteRange.parse(range) == nil {
                    return "This HLS stream contains an invalid initialization byte range and cannot be packaged safely for offline playback."
                }
                guard let uri = values["URI"], !uri.isEmpty else {
                    return "This HLS stream has an invalid initialization section and cannot be packaged safely for offline playback. Choose another stream."
                }
                if let initializationURI, initializationURI != uri {
                    return "This HLS stream changes initialization sections, which cannot be packaged safely for offline playback. Choose another stream."
                }
                initializationURI = uri
            }
        }
        return nil
    }
}

struct HLSEncryptionKey {
    let method: String
    let keyURL: URL
    let iv: Data?
}

private final class HLSRedirectPolicyDelegate: NSObject, URLSessionTaskDelegate {
    private let headers: [String: String]
    private let originURL: URL

    init(headers: [String: String], originURL: URL) {
        self.headers = headers
        self.originURL = originURL
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let source = response.url,
              let destination = request.url,
              HLSDownloadCompatibility.permitsRedirect(from: source, to: destination) else {
            completionHandler(nil)
            return
        }
        let safeHeaders = MPVHeaderProxy.shared.directTransportHeaders(
            headers,
            for: destination,
            originURL: originURL
        )
        var redirected = request
        for name in headers.keys {
            redirected.setValue(nil, forHTTPHeaderField: name)
        }
        for name in ["Authorization", "Cookie", "Proxy-Authorization", "X-Api-Key", "X-Auth-Token"] {
            redirected.setValue(nil, forHTTPHeaderField: name)
        }
        for (name, value) in safeHeaders {
            redirected.setValue(value, forHTTPHeaderField: name)
        }
        completionHandler(redirected)
    }
}

#if os(iOS) && !targetEnvironment(macCatalyst)
struct HLSBackgroundDownloadResult {
    let data: Data
    let response: URLResponse?
}

/// Background URLSession can fetch both HTTP and HTTPS media. Where a
/// source requires public-network validation, that separate dispatch check
/// still rejects private, loopback, and unsafe destinations; requiring HTTPS
/// here incorrectly rejected otherwise valid HTTP HLS resources first.
enum HLSBackgroundNetworkValidationPolicy {
    static func permits(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false,
              url.user == nil,
              url.password == nil else {
            return false
        }
        return true
    }
}

enum HLSBackgroundPlaylistResourcePlan {
    static let maximumResourceCount = 20_000

    static func resources(
        segments: [URL],
        startingAt startIndex: Int,
        initializationSegmentURL: URL?
    ) throws -> [URL] {
        guard startIndex >= 0, startIndex <= segments.count else {
            throw HLSError.unsupportedLayout(
                reason: "This HLS resume checkpoint points outside the media playlist. Restart the download."
            )
        }
        let resources = (initializationSegmentURL.map { [$0] } ?? []) + Array(segments.dropFirst(startIndex))
        guard resources.count <= maximumResourceCount else {
            throw HLSError.unsupportedLayout(
                reason: "This HLS playlist contains too many segments to queue safely for background downloading. Choose a shorter or pre-packaged stream."
            )
        }
        return resources
    }

    static func resources(
        segments: [HLSMediaResource],
        startingAt startIndex: Int,
        initializationSegment: HLSMediaResource?
    ) throws -> [HLSMediaResource] {
        guard startIndex >= 0, startIndex <= segments.count else {
            throw HLSError.unsupportedLayout(
                reason: "This HLS resume checkpoint points outside the media playlist. Restart the download."
            )
        }
        let resources = (initializationSegment.map { [$0] } ?? []) + Array(segments.dropFirst(startIndex))
        guard resources.count <= maximumResourceCount else {
            throw HLSError.unsupportedLayout(
                reason: "This HLS playlist contains too many segments to queue safely for background downloading. Choose a shorter or pre-packaged stream."
            )
        }
        return resources
    }
}

/// Downloads each HLS resource as an OS-managed background URLSession task.
/// Stable task descriptions and a small completed-file cache let a new
/// HLSDownloader reattach after iOS relaunches Eclipse for background events.
final class HLSBackgroundURLSessionCoordinator: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let identifier = "app.eclipse.soupy.hls-segments"
    static let shared = HLSBackgroundURLSessionCoordinator()

    private struct PendingRequest {
        let maximumResponseBytes: Int
        var continuations: [CheckedContinuation<HLSBackgroundDownloadResult, Error>]

        mutating func append(_ continuation: CheckedContinuation<HLSBackgroundDownloadResult, Error>) {
            continuations.append(continuation)
        }

        func resume(returning result: HLSBackgroundDownloadResult) {
            continuations.forEach { $0.resume(returning: result) }
        }

        func resume(throwing error: Error) {
            continuations.forEach { $0.resume(throwing: error) }
        }
    }

    private struct ResponseSnapshot: Codable {
        // Persist only non-secret response metadata. Never write a signed
        // provider URL, Set-Cookie, Location, or authorization-related headers
        // into the app's cache when a background task finishes after relaunch.
        let responseOrigin: String?
        let statusCode: Int?
        let headers: [String: String]
        let mimeType: String?
        let expectedContentLength: Int64
        let textEncodingName: String?

        init?(response: URLResponse?) {
            guard let response else { return nil }
            if let responseURL = response.url,
               var components = URLComponents(url: responseURL, resolvingAgainstBaseURL: false) {
                components.user = nil
                components.password = nil
                components.path = ""
                components.query = nil
                components.fragment = nil
                responseOrigin = components.url?.absoluteString
            } else {
                responseOrigin = nil
            }
            self.expectedContentLength = response.expectedContentLength
            self.mimeType = response.mimeType
            self.textEncodingName = response.textEncodingName
            if let http = response as? HTTPURLResponse {
                statusCode = http.statusCode
                let safeNames: Set<String> = [
                    "content-type", "content-length", "content-encoding",
                    "retry-after", "server", "cf-ray", "cf-mitigated"
                ]
                headers = http.allHeaderFields.reduce(into: [:]) { result, pair in
                    guard let name = pair.key as? String,
                          safeNames.contains(name.lowercased()) else { return }
                    result[name] = String(describing: pair.value)
                }
            } else {
                statusCode = nil
                headers = [:]
            }
        }

        func makeURLResponse(fallbackURL: URL?) -> URLResponse? {
            let url = responseOrigin.flatMap(URL.init(string:)) ?? fallbackURL
            guard let url else { return nil }
            if let statusCode {
                return HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                )
            }
            return URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: Int(exactly: expectedContentLength) ?? -1,
                textEncodingName: textEncodingName
            )
        }
    }

    private let queue = DispatchQueue(label: "app.eclipse.hls-background-url-session")
    private var pending: [String: PendingRequest] = [:]
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var oversizedTaskDescriptions = Set<String>()
    private var backgroundCompletionHandler: (() -> Void)?

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.timeoutIntervalForRequest = 600
        configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
    }

    func handleEvents(completionHandler: @escaping () -> Void) {
        queue.async {
            self.backgroundCompletionHandler = completionHandler
            _ = self.session
        }
    }

    func download(
        _ request: URLRequest,
        downloadID: String,
        maximumResponseBytes: Int,
        requiresPublicNetworkValidation: Bool
    ) async throws -> HLSBackgroundDownloadResult {
        let description = taskDescription(
            downloadID: downloadID,
            url: request.url,
            rangeHeader: request.value(forHTTPHeaderField: "Range"),
            maximumResponseBytes: maximumResponseBytes,
            requiresPublicNetworkValidation: requiresPublicNetworkValidation
        )
        if let cached = try queue.sync(execute: {
            try readCompletedResult(for: description, maximumResponseBytes: maximumResponseBytes, fallbackURL: request.url)
        }) {
            return cached
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if var existing = self.pending[description] {
                    // Resume/recovery can reach a resource whose OS-owned
                    // transfer is still running. Keep every waiter attached.
                    existing.append(continuation)
                    self.pending[description] = existing
                } else {
                    self.pending[description] = PendingRequest(
                        maximumResponseBytes: maximumResponseBytes,
                        continuations: [continuation]
                    )
                }
                self.session.getAllTasks { tasks in
                    self.queue.async {
                        guard self.pending[description] != nil else { return }
                        // A queued segment can finish between the initial
                        // cache lookup and getAllTasks. Recheck here so the
                        // foreground worker consumes the completed file
                        // instead of launching a duplicate network request.
                        if let cached = try? self.readCompletedResult(
                            for: description,
                            maximumResponseBytes: maximumResponseBytes,
                            fallbackURL: request.url
                        ) {
                            self.pending.removeValue(forKey: description)?.resume(returning: cached)
                            return
                        }
                        if let active = self.activeTasks[description] {
                            if active.state == .suspended { active.resume() }
                            return
                        }
                        if let existing = tasks.first(where: { $0.taskDescription == description }) as? URLSessionDownloadTask {
                            self.activeTasks[description] = existing
                            if existing.state == .suspended { existing.resume() }
                            return
                        }

                        var backgroundRequest = request
                        backgroundRequest.timeoutInterval = max(backgroundRequest.timeoutInterval, 600)
                        let task = self.session.downloadTask(with: backgroundRequest)
                        task.taskDescription = description
                        self.activeTasks[description] = task
                        task.resume()
                    }
                }
            }
        }
    }

    /// Enqueue every resource in a finite media playlist before the app can be
    /// suspended. A sequential async worker cannot create segment N+1 while
    /// iOS has suspended the process after segment N; pre-enqueuing lets the
    /// OS-owned background session continue the whole VOD playlist on its own.
    func schedule(
        _ requests: [URLRequest],
        downloadID: String,
        maximumResponseBytes: Int,
        requiresPublicNetworkValidation: Bool
    ) async {
        let entries = requests.compactMap { request -> (URLRequest, String)? in
            guard let url = request.url else { return nil }
            return (request, taskDescription(
                downloadID: downloadID,
                url: url,
                rangeHeader: request.value(forHTTPHeaderField: "Range"),
                maximumResponseBytes: maximumResponseBytes,
                requiresPublicNetworkValidation: requiresPublicNetworkValidation
            ))
        }
        guard !entries.isEmpty else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.session.getAllTasks { tasks in
                    self.queue.async {
                        var existingTasks: [String: URLSessionDownloadTask] = [:]
                        for task in tasks {
                            guard let description = task.taskDescription,
                                  let downloadTask = task as? URLSessionDownloadTask else { continue }
                            existingTasks[description] = downloadTask
                        }
                        for (request, description) in entries {
                            // A previous process may already have received and
                            // cached this resource while no HLS worker was alive.
                            // Reuse that durable result instead of downloading
                            // the same segment again after relaunch.
                            if self.hasCompletedResult(
                                for: description,
                                maximumResponseBytes: maximumResponseBytes
                            ) {
                                continue
                            }
                            if let existing = existingTasks[description] {
                                self.activeTasks[description] = existing
                                if existing.state == .suspended { existing.resume() }
                                continue
                            }
                            var backgroundRequest = request
                            backgroundRequest.timeoutInterval = max(backgroundRequest.timeoutInterval, 600)
                            let task = self.session.downloadTask(with: backgroundRequest)
                            task.taskDescription = description
                            self.activeTasks[description] = task
                            existingTasks[description] = task
                            task.resume()
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Ends only the in-process waiter. The OS-owned transfer is deliberately
    /// left alive; its completed file is cached for the next worker to consume.
    func detach(downloadID: String) {
        let prefix = taskPrefix(downloadID: downloadID)
        queue.async {
            let keys = self.pending.keys.filter { $0.hasPrefix(prefix) }
            for key in keys {
                guard let request = self.pending.removeValue(forKey: key) else { continue }
                request.resume(throwing: URLError(.cancelled))
            }
        }
    }

    /// Explicit user cancellation is different from iOS background expiration:
    /// cancel all OS tasks and remove cached segments for this download.
    func cancel(downloadID: String) {
        let prefix = taskPrefix(downloadID: downloadID)
        queue.async {
            let keys = self.pending.keys.filter { $0.hasPrefix(prefix) }
            for key in keys {
                guard let request = self.pending.removeValue(forKey: key) else { continue }
                request.resume(throwing: URLError(.cancelled))
            }
            let activeKeys = self.activeTasks.keys.filter { $0.hasPrefix(prefix) }
            for key in activeKeys {
                self.activeTasks.removeValue(forKey: key)?.cancel()
            }
            self.session.getAllTasks { tasks in
                tasks.filter { $0.taskDescription?.hasPrefix(prefix) == true }.forEach { $0.cancel() }
            }
            self.removeCachedResults(withPrefix: prefix)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let description = downloadTask.taskDescription,
              description.hasPrefix("eclipse-hls-v1-") else { return }
        let maximumBytes = queue.sync {
            pending[description]?.maximumResponseBytes ?? self.maximumBytes(from: description)
        }
        let size = Self.regularFileSize(at: location)
        guard size >= 0, size <= Int64(maximumBytes) else {
            try? FileManager.default.removeItem(at: location)
            queue.async {
                self.activeTasks.removeValue(forKey: description)
                if let request = self.pending.removeValue(forKey: description) {
                    request.resume(throwing: URLError(.dataLengthExceedsMaximum))
                }
            }
            return
        }

        do {
            let baseURL = cacheBaseURL(for: description)
            try FileManager.default.createDirectory(
                at: baseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: baseURL.path) {
                try FileManager.default.removeItem(at: baseURL)
            }
            try? FileManager.default.removeItem(at: responseURL(for: description))
            if let snapshot = ResponseSnapshot(response: downloadTask.response) {
                try? JSONEncoder().encode(snapshot).write(
                    to: responseURL(for: description),
                    options: .atomic
                )
            }
            try FileManager.default.moveItem(at: location, to: baseURL)

            queue.async {
                self.activeTasks.removeValue(forKey: description)
                guard let request = self.pending.removeValue(forKey: description) else {
                    // No worker survived the app suspension. Keep the completed
                    // resource on disk so the resumed worker doesn't fetch it again.
                    return
                }
                do {
                    let fileURL = self.cacheBaseURL(for: description)
                    let size = Self.regularFileSize(at: fileURL)
                    guard size >= 0, size <= Int64(request.maximumResponseBytes) else {
                        throw URLError(.dataLengthExceedsMaximum)
                    }
                    let data = try Data(contentsOf: fileURL)
                    let response = downloadTask.response
                    try? FileManager.default.removeItem(at: fileURL)
                    try? FileManager.default.removeItem(at: self.responseURL(for: description))
                    request.resume(
                        returning: HLSBackgroundDownloadResult(data: data, response: response)
                    )
                } catch {
                    request.resume(throwing: error)
                }
            }
        } catch {
            try? FileManager.default.removeItem(at: location)
            queue.async {
                self.activeTasks.removeValue(forKey: description)
                if let request = self.pending.removeValue(forKey: description) {
                    request.resume(throwing: error)
                }
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let description = downloadTask.taskDescription,
              description.hasPrefix("eclipse-hls-v1-") else { return }
        let maximumBytes = queue.sync {
            pending[description]?.maximumResponseBytes ?? self.maximumBytes(from: description)
        }
        if totalBytesWritten > Int64(maximumBytes)
            || totalBytesExpectedToWrite > Int64(maximumBytes) {
            queue.async { self.oversizedTaskDescriptions.insert(description) }
            downloadTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let description = task.taskDescription,
              description.hasPrefix("eclipse-hls-v1-") else { return }
        queue.async {
            self.activeTasks.removeValue(forKey: description)
            let exceededLimit = self.oversizedTaskDescriptions.remove(description) != nil
            let completionError = exceededLimit ? URLError(.dataLengthExceedsMaximum) : error
            guard let completionError,
                  let request = self.pending.removeValue(forKey: description) else { return }
            request.resume(throwing: completionError)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let source = response.url,
              let destination = request.url,
              HLSDownloadCompatibility.permitsRedirect(from: source, to: destination) else {
            completionHandler(nil)
            return
        }

        let origin = task.originalRequest?.url ?? source
        let requiresPublicRedirectValidation = task.taskDescription.map {
            requiresPublicValidation(for: $0)
        } ?? false
        let originalHeaders = task.originalRequest?.allHTTPHeaderFields ?? [:]
        let safeHeaders = MPVHeaderProxy.shared.directTransportHeaders(
            originalHeaders,
            for: destination,
            originURL: origin
        )
        var redirected = request
        for name in originalHeaders.keys {
            redirected.setValue(nil, forHTTPHeaderField: name)
        }
        for name in ["Authorization", "Cookie", "Proxy-Authorization", "X-Api-Key", "X-Auth-Token"] {
            redirected.setValue(nil, forHTTPHeaderField: name)
        }
        for (name, value) in safeHeaders {
            redirected.setValue(value, forHTTPHeaderField: name)
        }

        guard requiresPublicRedirectValidation else {
            completionHandler(redirected)
            return
        }
        Task {
            do {
                _ = try await SkyStreamRemoteURLPolicy.shared.validateRedirectForNetworkDispatch(
                    from: origin,
                    to: destination,
                    purpose: .mediaSegment
                )
                completionHandler(redirected)
            } catch {
                completionHandler(nil)
            }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        queue.async {
            let completion = self.backgroundCompletionHandler
            self.backgroundCompletionHandler = nil
            DispatchQueue.main.async { completion?() }
        }
    }

    private func taskPrefix(downloadID: String) -> String {
        "eclipse-hls-v1-\(digest(downloadID))-"
    }

    private func taskDescription(
        downloadID: String,
        url: URL?,
        rangeHeader: String? = nil,
        maximumResponseBytes: Int,
        requiresPublicNetworkValidation: Bool
    ) -> String {
        var urlValue = url?.absoluteString ?? "missing-url"
        if let rangeHeader { urlValue += "\nrange:\(rangeHeader)" }
        let boundedMaximum = min(max(maximumResponseBytes, 1), 128 * 1_024 * 1_024)
        let validationMode = requiresPublicNetworkValidation ? "public" : "user"
        return taskPrefix(downloadID: downloadID)
            + digest(urlValue)
            + "-\(boundedMaximum)-\(validationMode)"
    }

    private func maximumBytes(from description: String) -> Int {
        guard let value = description.split(separator: "-").reversed().compactMap({ Int($0) }).first,
              value > 0 else { return 128 * 1_024 * 1_024 }
        return min(value, 128 * 1_024 * 1_024)
    }

    private func requiresPublicValidation(for description: String) -> Bool {
        description.hasSuffix("-public")
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func cacheBaseURL(for description: String) -> URL {
        cacheDirectoryURL().appendingPathComponent(description + ".segment")
    }

    private func responseURL(for description: String) -> URL {
        cacheDirectoryURL().appendingPathComponent(description + ".response.json")
    }

    private func cacheDirectoryURL() -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HLSBackgroundSegments", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(values)
        return directory
    }

    private func readCompletedResult(
        for description: String,
        maximumResponseBytes: Int,
        fallbackURL: URL?
    ) throws -> HLSBackgroundDownloadResult? {
        let fileURL = cacheBaseURL(for: description)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modifiedAt = attributes?[.modificationDate] as? Date ?? .distantPast
        let cacheLifetime: TimeInterval = maximumResponseBytes <= 5 * 1_024 * 1_024
            ? 5 * 60
            : 24 * 60 * 60
        guard Date().timeIntervalSince(modifiedAt) <= cacheLifetime else {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: responseURL(for: description))
            return nil
        }
        let size = Self.regularFileSize(at: fileURL)
        guard size >= 0, size <= Int64(maximumResponseBytes) else {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: responseURL(for: description))
            throw URLError(.dataLengthExceedsMaximum)
        }
        let data = try Data(contentsOf: fileURL)
        let response = (try? Data(contentsOf: responseURL(for: description)))
            .flatMap { try? JSONDecoder().decode(ResponseSnapshot.self, from: $0) }
            .flatMap { $0.makeURLResponse(fallbackURL: fallbackURL) }
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: responseURL(for: description))
        return HLSBackgroundDownloadResult(data: data, response: response)
    }

    private func hasCompletedResult(for description: String, maximumResponseBytes: Int) -> Bool {
        let fileURL = cacheBaseURL(for: description)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modifiedAt = attributes?[.modificationDate] as? Date ?? .distantPast
        let cacheLifetime: TimeInterval = maximumResponseBytes <= 5 * 1_024 * 1_024
            ? 5 * 60
            : 24 * 60 * 60
        let size = Self.regularFileSize(at: fileURL)
        guard Date().timeIntervalSince(modifiedAt) <= cacheLifetime,
              size >= 0,
              size <= Int64(maximumResponseBytes) else {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: responseURL(for: description))
            return false
        }
        return true
    }

    private func removeCachedResults(withPrefix prefix: String, excluding description: String? = nil) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectoryURL(),
            includingPropertiesForKeys: nil
        ) else { return }
        for url in urls where url.lastPathComponent.hasPrefix(prefix)
            && (description.map { !url.lastPathComponent.hasPrefix($0) } ?? true) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func regularFileSize(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber else { return -1 }
        return size.int64Value
    }
}
#endif

struct HLSDownloadCheckpoint {
    let variantURL: URL
    let totalSegments: Int
    let manifestSHA256: String?
    let segmentIndex: Int
    let byteCount: Int64
}

final class HLSDownloader: @unchecked Sendable {

    private let streamURL: URL
    private let headers: [String: String]
    private let destinationURL: URL
    private let downloadId: String

    private let resumeFromSegment: Int

    private let resumeByteCount: Int64

    private let pinnedVariantURL: URL?

    private let expectedTotalSegments: Int
    private let expectedManifestSHA256: String?
    private let canonicalResumeURL: (URL) -> URL?

    private let enforcesConservativeDiskCapacityReserve: Bool
    private let durableCheckpoints: Bool
    private let usesBackgroundURLSession: Bool

    var usesBackgroundURLSessionForResources: Bool { usesBackgroundURLSession }
    private let requiresPublicNetworkValidationForBackgroundURLSession: Bool

    private var isCancelled = false
    private var cancellationError: HLSError = .cancelled
    private var workerTask: Task<Void, Never>?
    private var workerIsStarting = false
    private var sessionRetired = false
    private var didFinish = false
    private var continuedProcessingGranted = false
    private var lastSynchronizedCheckpoint: HLSDownloadCheckpoint?
    private let stateLock = NSLock()
    private let transportStateLock = NSLock()
    private var nextRequestStartByHost: [String: TimeInterval] = [:]
    private var rateLimitedUntilByHost: [String: TimeInterval] = [:]
    private var rateLimitCountByHost: [String: Int] = [:]
    private let requestStartInterval: TimeInterval
    private let session: URLSession
    #if canImport(UIKit)
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTaskGeneration: UUID?
    #elseif os(macOS)
    private var backgroundActivity: NSObjectProtocol?
    #endif

    var onProgress: ((Double) -> Void)?

    var onCompletion: ((Result<URL, Error>) -> Void)?

    var onVariantResolved: ((URL, Int) -> Void)?

    var onCheckpoint: ((Int, Int64) -> Void)?
    var onResumeManifestResolved: ((String?) -> Void)?
    var onFinalCheckpoint: ((HLSDownloadCheckpoint) async throws -> Void)?
    var onStageChanged: ((String) -> Void)?

    var checkpointSnapshot: HLSDownloadCheckpoint? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return lastSynchronizedCheckpoint
    }
    #if DEBUG
    var onBeforeRequestStartForTesting: ((URL) -> Void)?
    #endif

    init(streamURL: URL, headers: [String: String], destinationURL: URL, downloadId: String,
         resumeFromSegment: Int = 0, resumeByteCount: Int64 = 0,
         pinnedVariantURL: URL? = nil, expectedTotalSegments: Int = 0,
         expectedManifestSHA256: String? = nil,
         canonicalResumeURL: @escaping (URL) -> URL? = { $0 },
         minimumRequestStartInterval: TimeInterval? = nil,
         enforcesConservativeDiskCapacityReserve: Bool = false,
         durableCheckpoints: Bool = false,
         sessionConfiguration: URLSessionConfiguration? = nil,
         useBackgroundURLSession: Bool = false,
         requiresPublicNetworkValidationForBackgroundURLSession: Bool = false) {
        self.streamURL = streamURL
        self.headers = headers
        self.destinationURL = destinationURL
        self.downloadId = downloadId
        self.resumeFromSegment = resumeFromSegment
        self.resumeByteCount = resumeByteCount
        self.pinnedVariantURL = pinnedVariantURL
        self.expectedTotalSegments = expectedTotalSegments
        self.expectedManifestSHA256 = expectedManifestSHA256
        self.canonicalResumeURL = canonicalResumeURL
        self.enforcesConservativeDiskCapacityReserve = enforcesConservativeDiskCapacityReserve
        self.durableCheckpoints = durableCheckpoints
#if os(iOS) && !targetEnvironment(macCatalyst)
        self.usesBackgroundURLSession = useBackgroundURLSession && sessionConfiguration == nil
        if !self.usesBackgroundURLSession, sessionConfiguration == nil {
            let scheme = streamURL.scheme?.lowercased() ?? "missing"
            let host = streamURL.host?.lowercased() ?? "missing"
            let reason = useBackgroundURLSession
                ? "a custom URLSession configuration was supplied"
                : "the source is not a supported remote HTTP(S) endpoint"
            Logger.shared.log(
                "HLS: foreground-only resource transport selected scheme=\(scheme) host=\(host) reason=\(reason)",
                type: "Download"
            )
        }
#else
        self.usesBackgroundURLSession = false
#endif
        self.requiresPublicNetworkValidationForBackgroundURLSession =
            requiresPublicNetworkValidationForBackgroundURLSession
        self.requestStartInterval = max(
            minimumRequestStartInterval ?? Self.minimumRequestStartInterval,
            0
        )

        let config = sessionConfiguration ?? URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        self.session = URLSession(
            configuration: config,
            delegate: HLSRedirectPolicyDelegate(headers: headers, originURL: streamURL),
            delegateQueue: nil
        )
    }

    deinit {
        session.invalidateAndCancel()
    }

    func start() {
        stateLock.lock()
        guard workerTask == nil, !workerIsStarting, !sessionRetired else {
            stateLock.unlock()
            return
        }
        workerIsStarting = true
        isCancelled = false
        cancellationError = .cancelled
        didFinish = false
        lastSynchronizedCheckpoint = nil
        stateLock.unlock()

        beginBackgroundTask()

        stateLock.lock()
        let task = Task { [weak self] in
            guard let self = self else { return }
            defer {
                self.clearWorkerTask()
                self.endBackgroundTask()
            }

            do {

                try self.checkCancelled()
                let playlistContent = try await self.fetchPlaylist(url: self.streamURL)

                try self.checkCancelled()

                let resolvedPlaylist = try await self.resolveMediaPlaylist(
                    initialContent: playlistContent,
                    initialURL: self.streamURL,
                    pinnedVariantURL: self.pinnedVariantURL
                )
                let mediaPlaylistURL = resolvedPlaylist.url
                let mediaPlaylistContent = resolvedPlaylist.content

                try self.checkCancelled()

                if let reason = HLSDownloadCompatibility.unsupportedMediaLayout(in: mediaPlaylistContent) {
                    throw HLSError.unsupportedLayout(reason: reason)
                }
                if let reason = HLSDownloadCompatibility.unsupportedEncryptionLayout(in: mediaPlaylistContent) {
                    throw HLSError.unsupportedLayout(reason: reason)
                }
                guard let mediaSequenceNumber = HLSDownloadCompatibility.mediaSequenceNumber(in: mediaPlaylistContent) else {
                    throw HLSError.unsupportedLayout(reason: "This HLS playlist has an invalid media sequence number and cannot be packaged safely for offline playback.")
                }
                let segments = try self.parseMediaResources(mediaPlaylistContent, baseURL: mediaPlaylistURL)
                guard !segments.isEmpty else {
                    throw HLSError.noSegmentsFound
                }

                Logger.shared.log("HLS: Found \(segments.count) segments to download", type: "Download")

                let resolvedVariant = mediaPlaylistURL
                let totalSegmentCount = segments.count
                DispatchQueue.main.async { [weak self] in
                    self?.onVariantResolved?(resolvedVariant, totalSegmentCount)
                }

                let effectiveResumeSegment = self.resumeFromSegment
                guard Self.isValidResumePosition(
                    segment: effectiveResumeSegment,
                    totalSegments: segments.count,
                    expectedTotalSegments: self.expectedTotalSegments
                ) else {
                    throw HLSError.resumePlaylistChanged
                }

                let encryptionKey = try self.parseEncryptionKey(from: mediaPlaylistContent, baseURL: mediaPlaylistURL)
                var keyData: Data? = nil
                if let encKey = encryptionKey, encKey.method == "AES-128" {
                    self.publishStage("Downloading encryption key")
                    keyData = try await self.fetchDataWithRetry(
                        url: encKey.keyURL,
                        maximumResponseBytes: Self.maximumEncryptionKeyBytes
                    )
                    try self.checkCancelled()
                    Logger.shared.log("HLS: Downloaded AES-128 encryption key", type: "Download")
                }

                let initSegment = try self.parseInitSegmentResource(from: mediaPlaylistContent, baseURL: mediaPlaylistURL)
                let manifestSHA256 = Self.resumeManifestFingerprint(
                    mediaPlaylistContent,
                    playlistURL: mediaPlaylistURL,
                    keyData: keyData,
                    canonicalURL: self.canonicalResumeURL
                )
                if effectiveResumeSegment > 0 {
                    guard let expected = self.expectedManifestSHA256,
                          manifestSHA256 == expected else { throw HLSError.resumePlaylistChanged }
                }
                DispatchQueue.main.async { [weak self] in
                    self?.onResumeManifestResolved?(manifestSHA256)
                }

                try self.checkCancelled()

                try await self.downloadAndConcatenateSegments(
                    segments: segments,
                    mediaSequenceNumber: mediaSequenceNumber,
                    initSegment: initSegment,
                    encryptionKey: encryptionKey,
                    keyData: keyData,
                    to: self.destinationURL,
                    resumeFromSegment: effectiveResumeSegment,
                    resumeByteCount: self.resumeByteCount,
                    variantURL: mediaPlaylistURL,
                    manifestSHA256: manifestSHA256
                )

                if !self.durableCheckpoints { try self.checkCancelled() }

                Logger.shared.log("HLS: Download complete -> \(self.destinationURL.lastPathComponent)", type: "Download")
                self.finish(.success(self.destinationURL))

            } catch {
                if self.isCancellationError(error) {
                    self.finish(.failure(self.currentCancellationError()))
                } else {
                    let nsError = error as NSError
                    Logger.shared.log(
                        "HLS download failed domain=\(Self.safeErrorDomain(nsError.domain))"
                            + " code=\(nsError.code)",
                        type: "Download"
                    )
                    self.finish(.failure(error))
                }
            }
        }

        workerTask = task
        workerIsStarting = false
        let cancelledWhileStarting = isCancelled
        stateLock.unlock()
        if cancelledWhileStarting { task.cancel() }
    }

    func cancel(reason: HLSError = .cancelled) {
        let task: Task<Void, Never>?
        let retiresIdleSession: Bool
        stateLock.lock()
        isCancelled = true
        cancellationError = reason
        task = workerTask
        retiresIdleSession = task == nil && !workerIsStarting && !sessionRetired
        if retiresIdleSession { sessionRetired = true }
        stateLock.unlock()

        task?.cancel()
#if os(iOS) && !targetEnvironment(macCatalyst)
        if usesBackgroundURLSession {
            switch reason {
            case .backgroundTimeExpired, .backgroundProcessingExpired:
                HLSBackgroundURLSessionCoordinator.shared.detach(downloadID: downloadId)
            default:
                HLSBackgroundURLSessionCoordinator.shared.cancel(downloadID: downloadId)
            }
        }
#endif
        if retiresIdleSession { session.invalidateAndCancel() }
        if !durableCheckpoints || retiresIdleSession { endBackgroundTask() }
    }

    func waitForCheckpoint() async {
        let task = checkpointTask()
        await task?.value
    }

    #if os(macOS)
    func waitForMacCheckpoint() async {
        await waitForCheckpoint()
    }
    #endif

    private func checkpointTask() -> Task<Void, Never>? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return workerTask
    }

    func setContinuedProcessingGranted(_ granted: Bool) {
        stateLock.lock()
        continuedProcessingGranted = granted
        let active = (workerTask != nil || workerIsStarting) && !isCancelled && !didFinish
        stateLock.unlock()
        if granted {
            endBackgroundTask()
        } else if active {
            beginBackgroundTask()
        }
    }

    private func beginBackgroundTask() {
        #if canImport(UIKit) && !os(watchOS)
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.beginBackgroundTask() }
            return
        }
        stateLock.lock()
        let allowed = !continuedProcessingGranted && !isCancelled && !didFinish
            && (workerTask != nil || workerIsStarting)
        stateLock.unlock()
        guard allowed else { return }
        guard backgroundTaskId == .invalid else { return }
        let generation = UUID()
        backgroundTaskGeneration = generation
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "HLSDownload-\(downloadId)") { [weak self] in
            guard let self, self.backgroundTaskGeneration == generation else { return }
            self.stateLock.lock()
            let continuedProcessingGranted = self.continuedProcessingGranted
            self.stateLock.unlock()
            guard !continuedProcessingGranted else { return }
            if self.usesBackgroundURLSession {
                // URLSession owns the network transfer now. Do not cancel the
                // worker or its OS task when UIKit's short execution window ends.
                self.endBackgroundTask()
                return
            }
            self.cancel(reason: .backgroundTimeExpired)
        }
        #elseif os(macOS)
        stateLock.lock()
        if backgroundActivity == nil {
            backgroundActivity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Finishing an Eclipse download")
        }
        stateLock.unlock()
        #endif
    }

    private func endBackgroundTask() {
        #if canImport(UIKit) && !os(watchOS)
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.endBackgroundTask() }
            return
        }
        guard backgroundTaskId != .invalid else { return }
        backgroundTaskGeneration = nil
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
        #elseif os(macOS)
        stateLock.lock()
        let activity = backgroundActivity
        backgroundActivity = nil
        stateLock.unlock()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        #endif
    }

    private static let maximumPlaylistBytes = 5 * 1024 * 1024
    private static let maximumEncryptionKeyBytes = 64 * 1024
    private static let maximumMediaObjectBytes = 128 * 1024 * 1024
    private static let minimumRequestStartInterval: TimeInterval = 0.15
    private static let maximumRetryAfterSeconds: TimeInterval = 30
    private static let minimumFreeCapacityReserve: Int64 = 512 * 1024 * 1024

    /// Follow nested HLS master playlists until a concrete media playlist is
    /// reached. A number of providers publish master → rendition-master →
    /// media-playlist chains; treating the second master as an unsupported
    /// layout made otherwise valid HLS download URLs fail before segment work.
    private func resolveMediaPlaylist(
        initialContent: String,
        initialURL: URL,
        pinnedVariantURL: URL?
    ) async throws -> (url: URL, content: String) {
        var currentURL = initialURL
        var currentContent = initialContent
        if let pinnedVariantURL, pinnedVariantURL != initialURL {
            currentURL = pinnedVariantURL
            currentContent = try await fetchPlaylist(url: pinnedVariantURL)
        }

        let maximumMasterDepth = 5
        var depth = 0
        while isMasterPlaylist(currentContent) {
            try checkCancelled()
            guard depth < maximumMasterDepth else {
                throw HLSError.unsupportedLayout(
                    reason: "This HLS stream contains too many nested variant playlists to download safely."
                )
            }
            let variants = parseMasterPlaylist(currentContent, baseURL: currentURL)
            guard let best = selectBestVariant(variants) else {
                if !variants.isEmpty {
                    throw HLSError.unsupportedLayout(reason: HLSDownloadCompatibility.separateAudioMessage)
                }
                throw HLSError.noVariantsFound
            }
            Logger.shared.log(
                "HLS: Selected variant \(best.resolution ?? "unknown") @ \(best.bandwidth)bps (master depth \(depth + 1))",
                type: "Download"
            )
            currentURL = best.url
            currentContent = try await fetchPlaylist(url: best.url)
            depth += 1
        }
        return (currentURL, currentContent)
    }

    private func fetchPlaylist(url: URL) async throws -> String {
        publishStage("Downloading playlist")
        let data = try await fetchDataWithRetry(
            url: url,
            maximumResponseBytes: Self.maximumPlaylistBytes
        )
        guard let content = String(data: data, encoding: .utf8) else {
            throw HLSError.invalidPlaylistData
        }
        return content
    }

    private func makeTransportRequest(for url: URL) -> (URLRequest, [String: String]) {
        let effectiveHeaders = CloudflareBypassManager.shared.headersByApplyingCachedBypass(headers, for: url)
        let transportHeaders = MPVHeaderProxy.shared.directTransportHeaders(
            effectiveHeaders,
            for: url,
            originURL: streamURL
        )
        var request = URLRequest(url: url)
        for (key, value) in transportHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return (request, effectiveHeaders)
    }

    private func scheduleBackgroundPlaylistResources(
        segments: [HLSMediaResource],
        startingAt startIndex: Int,
        initializationSegment: HLSMediaResource?
    ) async throws {
#if os(iOS) && !targetEnvironment(macCatalyst)
        guard usesBackgroundURLSession else { return }
        let resources = try HLSBackgroundPlaylistResourcePlan.resources(
            segments: segments,
            startingAt: startIndex,
            initializationSegment: initializationSegment
        )
        var requests: [URLRequest] = []
        requests.reserveCapacity(resources.count)
        for resource in resources {
            try checkCancelled()
            let url = resource.url
            if requiresPublicNetworkValidationForBackgroundURLSession {
                guard HLSBackgroundNetworkValidationPolicy.permits(url) else {
                    throw HLSError.unsupportedLayout(reason: "This protected HLS resource has an unsupported network URL.")
                }
                do {
                    _ = try await SkyStreamRemoteURLPolicy.shared.validateForNetworkDispatch(
                        url.absoluteString,
                        purpose: .mediaSegment
                    )
                } catch {
                    throw HLSError.unsupportedLayout(
                        reason: "An HLS resource was rejected by the protected-source network policy."
                    )
                }
            }
            var request = makeTransportRequest(for: url).0
            resource.apply(to: &request)
            request.timeoutInterval = 600
            requests.append(request)
        }
        await HLSBackgroundURLSessionCoordinator.shared.schedule(
            requests,
            downloadID: downloadId,
            maximumResponseBytes: Self.maximumMediaObjectBytes,
            requiresPublicNetworkValidation: requiresPublicNetworkValidationForBackgroundURLSession
        )
        do {
            try checkCancelled()
        } catch {
            // Cancellation can race URLSession's asynchronous getAllTasks
            // callback. Remove anything the batch may have queued after the
            // user's Cancel/Delete action reached the coordinator.
            HLSBackgroundURLSessionCoordinator.shared.cancel(downloadID: downloadId)
            throw error
        }
        Logger.shared.log(
            "HLS background: queued \(requests.count) playlist resource(s) before segment processing",
            type: "Download"
        )
#endif
    }

    private func fetchData(
        url: URL,
        byteRange: HLSByteRange? = nil,
        maximumResponseBytes: Int = HLSDownloader.maximumMediaObjectBytes
    ) async throws -> Data {
        try checkCancelled()
        try await waitForRequestStartSlot(for: url)
        publishStage("Downloading HLS data")

        var (request, effectiveHeaders) = makeTransportRequest(for: url)
        if let byteRange {
            guard byteRange.headerValue != nil else {
                throw HLSError.unsupportedLayout(reason: "This HLS byte range is invalid.")
            }
            request.setValue(byteRange.headerValue, forHTTPHeaderField: "Range")
        }

        #if DEBUG
        onBeforeRequestStartForTesting?(url)
        #endif
        let data: Data
        let response: URLResponse?
#if os(iOS) && !targetEnvironment(macCatalyst)
        if usesBackgroundURLSession {
            if requiresPublicNetworkValidationForBackgroundURLSession {
                guard HLSBackgroundNetworkValidationPolicy.permits(url) else {
                    throw HLSError.unsupportedLayout(reason: "This protected HLS resource has an unsupported network URL.")
                }
                do {
                    _ = try await SkyStreamRemoteURLPolicy.shared.validateForNetworkDispatch(
                        url.absoluteString,
                        purpose: .mediaSegment
                    )
                } catch {
                    throw HLSError.unsupportedLayout(
                        reason: "An HLS resource was rejected by the protected-source network policy."
                    )
                }
            }
            let result = try await HLSBackgroundURLSessionCoordinator.shared.download(
                request,
                downloadID: downloadId,
                maximumResponseBytes: maximumResponseBytes,
                requiresPublicNetworkValidation: requiresPublicNetworkValidationForBackgroundURLSession
            )
            data = result.data
            response = result.response
        } else {
            (data, response) = try await session.boundedData(
                for: request,
                maximumResponseBytes: maximumResponseBytes
            )
        }
#else
        (data, response) = try await session.boundedData(
            for: request,
            maximumResponseBytes: maximumResponseBytes
        )
#endif
        try checkCancelled()

        if let httpResponse = response as? HTTPURLResponse {
            let bodyPreview = String(data: data.prefix(1_000_000), encoding: .utf8) ?? ""
            if CloudflareBypassManager.isChallengeResponse(
                status: httpResponse.statusCode,
                body: bodyPreview,
                headers: CloudflareBypassManager.headersDictionary(from: httpResponse)
            ) {
                let rejectedCookieHeader = effectiveHeaders.first {
                    $0.key.caseInsensitiveCompare("Cookie") == .orderedSame
                }?.value
                throw HLSError.cloudflareVerificationRequired(
                    url: httpResponse.url ?? url,
                    rejectedCookieHeader: rejectedCookieHeader
                )
            }
            if httpResponse.statusCode == 429 {
                throw HLSError.rateLimited(
                    retryAfterSeconds: Self.retryAfterSeconds(from: httpResponse)
                )
            }
            if !(200...299).contains(httpResponse.statusCode) {
                throw HLSError.httpError(statusCode: httpResponse.statusCode)
            }
            clearRateLimitState(for: url)
        }

        if let byteRange {
            guard let httpResponse = response as? HTTPURLResponse,
                  let expectedEnd = byteRange.upperBound else {
                throw HLSError.unsupportedLayout(reason: "The HLS server did not return a verifiable byte-range response.")
            }
            if httpResponse.statusCode == 206 {
                let expectedRange = "bytes \(byteRange.offset)-\(expectedEnd)"
                guard let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range") else {
                    throw HLSError.unsupportedLayout(reason: "The HLS server returned an unexpected byte range.")
                }
                let contentRangeParts = contentRange.split(separator: "/", maxSplits: 1)
                guard contentRangeParts.count == 2,
                      contentRangeParts[0] == Substring(expectedRange),
                      contentRangeParts[1] == "*" || Int64(contentRangeParts[1]).map({ $0 > expectedEnd }) == true,
                      Int64(data.count) == byteRange.length else {
                    throw HLSError.unsupportedLayout(reason: "The HLS server returned an unexpected byte range.")
                }
            } else if httpResponse.statusCode == 200,
                      byteRange.offset == 0,
                      Int64(data.count) == byteRange.length {
                // A few CDNs ignore Range for a complete resource that is
                // already exactly the requested size. This is safe only at 0.
            } else if httpResponse.statusCode == 200 {
                let (exclusiveUpper, overflow) = expectedEnd.addingReportingOverflow(1)
                guard !overflow,
                      let lower = Int(exactly: byteRange.offset),
                      let upper = Int(exactly: exclusiveUpper),
                      data.count > upper else {
                    throw HLSError.unsupportedLayout(reason: "The HLS server ignored or rejected a required byte-range request.")
                }
                return data.subdata(in: lower..<upper)
            } else {
                throw HLSError.unsupportedLayout(reason: "The HLS server ignored or rejected a required byte-range request.")
            }
        }
        return data
    }

    private func fetchDataWithRetry(
        url: URL,
        byteRange: HLSByteRange? = nil,
        maximumResponseBytes: Int = HLSDownloader.maximumMediaObjectBytes,
        maxRetries: Int = 3
    ) async throws -> Data {
        let attemptCount = max(maxRetries, 1)
        var lastError: Error = HLSError.unknownError

        for attempt in 0..<attemptCount {
            do {
                return try await fetchData(url: url, byteRange: byteRange, maximumResponseBytes: maximumResponseBytes)
            } catch {
                lastError = error
                if isCancellationError(error) { throw currentCancellationError() }

                if let hlsError = error as? HLSError {
                    switch hlsError {
                    case .cloudflareVerificationRequired:

                        throw hlsError
                    case .rateLimited(let retryAfterSeconds):
                        let delay = recordRateLimit(for: url, retryAfterSeconds: retryAfterSeconds)
                        if attempt < attemptCount - 1 {
                            Logger.shared.log(
                                "HLS: CDN rate limit host=\(url.host?.lowercased() ?? "unknown") retryIn=\(String(format: "%.1f", delay))s attempt=\(attempt + 1)/\(attemptCount)",
                                type: "Download"
                            )
                        }

                        continue
                    default:
                        break
                    }
                }

                if attempt < attemptCount - 1 {
                    publishStage("Waiting to retry download")
                    let delay = min(pow(2.0, Double(attempt)), 8)
                    try await Task.sleep(nanoseconds: Self.nanoseconds(for: delay))
                    try checkCancelled()
                }
            }
        }

        throw lastError
    }

    private func waitForRequestStartSlot(for url: URL) async throws {
        let scheduledStart = reserveRequestStart(for: url)
        let delay = max(0, scheduledStart - ProcessInfo.processInfo.systemUptime)
        if delay > 0 {
            publishStage("Waiting for download request")
            try await Task.sleep(nanoseconds: Self.nanoseconds(for: delay))
            try checkCancelled()
        }
    }

    private func publishStage(_ stage: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onStageChanged?(stage)
        }
    }

    private func reserveRequestStart(for url: URL) -> TimeInterval {
        let host = url.host?.lowercased() ?? "unknown"
        let now = ProcessInfo.processInfo.systemUptime
        transportStateLock.lock()
        defer { transportStateLock.unlock() }
        let scheduledStart = max(
            now,
            max(
                nextRequestStartByHost[host] ?? now,
                rateLimitedUntilByHost[host] ?? now
            )
        )
        nextRequestStartByHost[host] = scheduledStart + requestStartInterval
        return scheduledStart
    }

    private func recordRateLimit(for url: URL, retryAfterSeconds: TimeInterval?) -> TimeInterval {
        let host = url.host?.lowercased() ?? "unknown"
        let now = ProcessInfo.processInfo.systemUptime

        transportStateLock.lock()
        let count = min((rateLimitCountByHost[host] ?? 0) + 1, 4)
        rateLimitCountByHost[host] = count
        let exponentialDelay = pow(2.0, Double(count - 1))
        let finiteRetryAfter = retryAfterSeconds.flatMap { $0.isFinite ? $0 : nil }
        let serverDelay = min(max(finiteRetryAfter ?? 0, 0), Self.maximumRetryAfterSeconds)
        let delay = max(exponentialDelay, serverDelay)
        let limitedUntil = now + delay
        rateLimitedUntilByHost[host] = max(rateLimitedUntilByHost[host] ?? 0, limitedUntil)
        nextRequestStartByHost[host] = max(nextRequestStartByHost[host] ?? 0, limitedUntil)
        transportStateLock.unlock()

        return delay
    }

    private func clearRateLimitState(for url: URL) {
        let host = url.host?.lowercased() ?? "unknown"
        transportStateLock.lock()
        rateLimitedUntilByHost.removeValue(forKey: host)
        rateLimitCountByHost.removeValue(forKey: host)
        transportStateLock.unlock()
    }

    static func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let rawValue = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else { return nil }

        if let seconds = TimeInterval(rawValue), seconds.isFinite {
            return min(max(seconds, 0), maximumRetryAfterSeconds)
        }

        let formatter = AppCalendar.dateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in [
            "EEE',' dd MMM yyyy HH':'mm':'ss z",
            "EEEE',' dd-MMM-yy HH':'mm':'ss z",
            "EEE MMM d HH':'mm':'ss yyyy"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: rawValue) {
                let seconds = date.timeIntervalSinceNow
                guard seconds.isFinite else { return nil }
                return min(max(seconds, 0), maximumRetryAfterSeconds)
            }
        }
        return nil
    }

    static func nanoseconds(for seconds: TimeInterval) -> UInt64 {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        let rounded = (seconds * 1_000_000_000).rounded(.up)
        guard rounded.isFinite else { return UInt64.max }
        guard rounded > 0 else { return 0 }
        return UInt64(exactly: rounded) ?? UInt64.max
    }

    private static func safeErrorDomain(_ value: String) -> String {
        let filtered = value.unicodeScalars.filter { scalar in
            scalar.isASCII && (
                CharacterSet.alphanumerics.contains(scalar)
                    || scalar == "." || scalar == "-" || scalar == "_"
            )
        }
        let bounded = String(filtered.prefix(64))
        return bounded.isEmpty ? "network" : bounded
    }

    private func isMasterPlaylist(_ content: String) -> Bool {
        return content.contains("#EXT-X-STREAM-INF")
    }

    func parseMasterPlaylist(_ content: String, baseURL: URL) -> [HLSVariant] {
        var variants: [HLSVariant] = []
        let audioGroups = HLSDownloadCompatibility.muxedAudioGroups(in: content)
        let lines = content.components(separatedBy: .newlines)

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                let attributes = line.replacingOccurrences(of: "#EXT-X-STREAM-INF:", with: "")
                let bandwidth = parseAttribute(attributes, key: "BANDWIDTH").flatMap { Int($0) } ?? 0
                let resolution = parseAttribute(attributes, key: "RESOLUTION")

                i += 1
                while i < lines.count {
                    let uri = lines[i].trimmingCharacters(in: .whitespaces)
                    if !uri.isEmpty && !uri.hasPrefix("#") {
                        if let variantURL = resolveURL(uri, baseURL: baseURL) {
                            let requiresExternalAudio = HLSDownloadCompatibility.requiresExternalAudio(
                                attributes: HLSDownloadCompatibility.attributes(attributes), groups: audioGroups
                            )
                            variants.append(HLSVariant(url: variantURL, bandwidth: bandwidth, resolution: resolution, requiresExternalAudio: requiresExternalAudio))
                        }
                        break
                    }
                    i += 1
                }
            }
            i += 1
        }

        return variants
    }

    func selectBestVariant(_ variants: [HLSVariant]) -> HLSVariant? {

        return variants.filter { !$0.requiresExternalAudio }.max(by: { $0.bandwidth < $1.bandwidth })
    }

    func parseMediaPlaylist(_ content: String, baseURL: URL) throws -> [URL] {
        try parseMediaResources(content, baseURL: baseURL).map(\.url)
    }

    func parseMediaResources(_ content: String, baseURL: URL) throws -> [HLSMediaResource] {
        var segments: [HLSMediaResource] = []
        var pendingRange: String?
        var previousRangeURL: URL?
        var previousRangeEnd: Int64?
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#EXT-X-BYTERANGE:") {
                guard pendingRange == nil else {
                    throw HLSError.unsupportedLayout(reason: "This HLS playlist contains multiple byte ranges for one segment.")
                }
                pendingRange = String(trimmed.dropFirst("#EXT-X-BYTERANGE:".count))
                continue
            }
            if trimmed.hasPrefix("#") { continue }
            guard let segmentURL = resolveURL(trimmed, baseURL: baseURL) else {
                throw HLSError.unsupportedLayout(reason: "This HLS playlist contains an invalid segment URL and cannot be packaged safely for offline playback. Choose another stream.")
            }
            var byteRange: HLSByteRange?
            if let pendingRange {
                let implicitOffset: Int64?
                if previousRangeURL == segmentURL, let previousRangeEnd {
                    let (nextOffset, overflow) = previousRangeEnd.addingReportingOverflow(1)
                    implicitOffset = overflow ? nil : nextOffset
                } else {
                    implicitOffset = nil
                }
                guard let parsed = HLSByteRange.parse(pendingRange, implicitOffset: implicitOffset),
                      let end = parsed.upperBound else {
                    throw HLSError.unsupportedLayout(reason: "This HLS playlist contains an invalid or ambiguous byte range.")
                }
                byteRange = parsed
                previousRangeURL = segmentURL
                previousRangeEnd = end
            } else {
                previousRangeURL = nil
                previousRangeEnd = nil
            }
            segments.append(HLSMediaResource(url: segmentURL, byteRange: byteRange))
            pendingRange = nil
        }
        guard pendingRange == nil else {
            throw HLSError.unsupportedLayout(reason: "This HLS playlist ends with a byte range that has no media segment.")
        }
        return segments
    }

    private func parseEncryptionKey(from content: String, baseURL: URL) throws -> HLSEncryptionKey? {
        let lines = content.components(separatedBy: .newlines)

        var lastKey: HLSEncryptionKey? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#EXT-X-KEY:") else { continue }

            let attributes = trimmed.replacingOccurrences(of: "#EXT-X-KEY:", with: "")
            guard let rawMethod = parseAttribute(attributes, key: "METHOD"),
                  !rawMethod.isEmpty else {
                throw HLSError.unsupportedLayout(reason: "This HLS stream has an invalid encryption declaration and cannot be packaged safely for offline playback. Choose another stream.")
            }
            let method = rawMethod.uppercased()

            if method == "NONE" {
                lastKey = nil
                continue
            }

            guard let uriString = parseAttribute(attributes, key: "URI"),
                  HLSDownloadCompatibility.isValidAES128KeyURL(uriString, relativeTo: baseURL),
                  let keyURL = resolveURL(uriString, baseURL: baseURL) else {
                throw HLSError.unsupportedLayout(reason: "This HLS stream has an invalid AES-128 key URL and cannot be packaged safely for offline playback. Choose another stream.")
            }

            var ivData: Data? = nil
            if let ivString = parseAttribute(attributes, key: "IV") {
                guard HLSDownloadCompatibility.isValidAES128IV(ivString),
                      let parsedIV = hexStringToData(ivString),
                      parsedIV.count == kCCBlockSizeAES128 else {
                    throw HLSError.unsupportedLayout(reason: "This HLS stream has an invalid AES-128 initialization vector and cannot be packaged safely for offline playback. Choose another stream.")
                }
                ivData = parsedIV
            }

            lastKey = HLSEncryptionKey(method: method, keyURL: keyURL, iv: ivData)
        }

        return lastKey
    }

    func parseInitSegmentResource(from content: String, baseURL: URL) throws -> HLSMediaResource? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("#EXT-X-MAP:") else { continue }
            let attributes = String(trimmed.dropFirst("#EXT-X-MAP:".count))
            guard let uriString = parseAttribute(attributes, key: "URI"),
                  let initURL = resolveURL(uriString, baseURL: baseURL) else {
                throw HLSError.unsupportedLayout(reason: "This HLS stream has an invalid initialization segment URL and cannot be packaged safely for offline playback. Choose another stream.")
            }
            var range: HLSByteRange?
            if let value = parseAttribute(attributes, key: "BYTERANGE") {
                guard let parsed = HLSByteRange.parse(value) else {
                    throw HLSError.unsupportedLayout(reason: "This HLS stream has an invalid initialization byte range.")
                }
                range = parsed
            }
            return HLSMediaResource(url: initURL, byteRange: range)
        }
        return nil
    }

    private func downloadAndConcatenateSegments(
        segments: [HLSMediaResource],
        mediaSequenceNumber: UInt64,
        initSegment: HLSMediaResource?,
        encryptionKey: HLSEncryptionKey?,
        keyData: Data?,
        to outputURL: URL,
        resumeFromSegment: Int,
        resumeByteCount: Int64,
        variantURL: URL,
        manifestSHA256: String?
    ) async throws {
        try checkSystemBackoff()
        guard resumeFromSegment >= 0, resumeFromSegment <= segments.count, resumeByteCount >= 0 else {
            throw HLSError.resumePlaylistChanged
        }

        let partialURL = outputURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(outputURL.lastPathComponent).partial")
        var completed = false
        var preservePartial = false

        let partialSize = Self.fileSize(at: partialURL)
        if durableCheckpoints,
           !FileManager.default.fileExists(atPath: partialURL.path),
           resumeFromSegment == segments.count,
           expectedTotalSegments == segments.count,
           resumeByteCount > 0,
           Self.isRegularFile(at: outputURL, exactSize: resumeByteCount) {
            try confirmRecoveredOutput(
                HLSDownloadCheckpoint(
                    variantURL: variantURL,
                    totalSegments: segments.count,
                    manifestSHA256: manifestSHA256,
                    segmentIndex: resumeFromSegment,
                    byteCount: resumeByteCount
                )
            )
            return
        }
        let isResuming = resumeFromSegment > 0
            && resumeByteCount > 0
            && partialSize >= resumeByteCount

        if resumeFromSegment > 0, !isResuming {
            throw HLSError.resumeCheckpointMissing
        }

        let fileHandle: FileHandle
        if isResuming {
            fileHandle = try FileHandle(forWritingTo: partialURL)
            try fileHandle.truncate(atOffset: UInt64(resumeByteCount))
            try fileHandle.seekToEnd()
            if durableCheckpoints {
                try fileHandle.synchronize()
                captureCheckpoint(HLSDownloadCheckpoint(
                    variantURL: variantURL,
                    totalSegments: segments.count,
                    manifestSHA256: manifestSHA256,
                    segmentIndex: resumeFromSegment,
                    byteCount: resumeByteCount
                ))
            }
            Logger.shared.log("HLS: resuming from segment \(resumeFromSegment) (\(resumeByteCount) bytes on disk)", type: "Download")
        } else {
            try? FileManager.default.removeItem(at: partialURL)
            guard FileManager.default.createFile(atPath: partialURL.path, contents: nil) else {
                throw HLSError.couldNotCreateOutput
            }
            fileHandle = try FileHandle(forWritingTo: partialURL)
        }

        defer {
            try? fileHandle.close()

            if !completed && !preservePartial {
                try? FileManager.default.removeItem(at: partialURL)
            }
        }

        do {
            try ensureDiskCapacity()

            let totalSegments = segments.count
            let startIndex = isResuming ? resumeFromSegment : 0

            // Create OS-owned download tasks for the complete remaining
            // playlist before awaiting any one segment. This is the key
            // background-continuation requirement: iOS may suspend the Swift
            // worker between segment requests, but URLSession keeps every
            // already-enqueued transfer alive and delivers completed files
            // when Eclipse is relaunched or foregrounded.
            try await scheduleBackgroundPlaylistResources(
                segments: segments,
                startingAt: startIndex,
                initializationSegment: isResuming ? nil : initSegment
            )

            if !isResuming, let initSegment {
                publishStage("Downloading initialization segment")
                try checkSystemBackoff()
                try ensureDiskCapacity()
                let initData = try await fetchDataWithRetry(url: initSegment.url, byteRange: initSegment.byteRange)
                try checkCancelled()
                // Encrypted EXT-X-MAP sections require an explicit IV.
                let decrypted = try decryptIfNeeded(
                    data: initData,
                    key: encryptionKey,
                    keyData: keyData,
                    defaultSequenceNumber: nil
                )
                try ensureDiskCapacity(additionalBytes: Int64(decrypted.count))
                try fileHandle.write(contentsOf: decrypted)
            }

            for index in startIndex..<totalSegments {
                publishStage("Downloading video segment")
                try checkCancelled()
                try checkSystemBackoff()
                try ensureDiskCapacity()

                let segmentData = try await fetchSegmentWithRetry(resource: segments[index], maxRetries: 3)
                try checkCancelled()
                guard let sequenceNumber = HLSDownloadCompatibility.sequenceNumber(
                    base: mediaSequenceNumber,
                    segmentIndex: index
                ) else {
                    throw HLSError.unsupportedLayout(reason: "This HLS playlist's media sequence number is too large to decrypt safely.")
                }
                let decrypted = try decryptIfNeeded(
                    data: segmentData,
                    key: encryptionKey,
                    keyData: keyData,
                    defaultSequenceNumber: sequenceNumber
                )
                try ensureDiskCapacity(additionalBytes: Int64(decrypted.count))

                try fileHandle.write(contentsOf: decrypted)
                if durableCheckpoints {
                    try fileHandle.synchronize()
                } else {
                    #if os(macOS)
                    try fileHandle.synchronize()
                    #endif
                }

                let writtenSegments = index + 1
                guard let byteOffset = Int64(exactly: try fileHandle.offset()) else {
                    throw HLSError.couldNotCreateOutput
                }
                if durableCheckpoints {
                    captureCheckpoint(HLSDownloadCheckpoint(
                        variantURL: variantURL,
                        totalSegments: totalSegments,
                        manifestSHA256: manifestSHA256,
                        segmentIndex: writtenSegments,
                        byteCount: byteOffset
                    ))
                }
                let progress = Double(writtenSegments) / Double(totalSegments)
                DispatchQueue.main.async { [weak self] in
                    self?.onProgress?(progress)
                    self?.onCheckpoint?(writtenSegments, byteOffset)
                }
            }

            try fileHandle.synchronize()
            try fileHandle.close()
            if durableCheckpoints {
                publishStage("Saving downloaded video")
                guard let checkpoint = checkpointSnapshot,
                      checkpoint.segmentIndex == totalSegments else {
                    throw HLSError.resumeCheckpointMissing
                }
                try await onFinalCheckpoint?(checkpoint)
                try commitOutput(partialURL: partialURL, outputURL: outputURL)
            } else {
                try? FileManager.default.removeItem(at: outputURL)
                try FileManager.default.moveItem(at: partialURL, to: outputURL)
            }
            completed = true
        } catch {
            if durableCheckpoints {
                try? fileHandle.synchronize()
                try? fileHandle.close()
            }
            preservePartial = true
            throw error
        }
    }

    private func captureCheckpoint(_ checkpoint: HLSDownloadCheckpoint) {
        stateLock.lock()
        lastSynchronizedCheckpoint = checkpoint
        stateLock.unlock()
    }

    private func confirmRecoveredOutput(_ checkpoint: HLSDownloadCheckpoint) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        if isCancelled { throw cancellationError }
        if Task.isCancelled { throw HLSError.cancelled }
        lastSynchronizedCheckpoint = checkpoint
    }

    private func commitOutput(partialURL: URL, outputURL: URL) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        if isCancelled { throw cancellationError }
        if Task.isCancelled { throw HLSError.cancelled }
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw HLSError.couldNotCreateOutput
        }
        try FileManager.default.moveItem(at: partialURL, to: outputURL)
    }

    private static func isRegularFile(at url: URL, exactSize: Int64) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? Int64 else { return false }
        return size == exactSize
    }

    private func fetchSegmentWithRetry(resource: HLSMediaResource, maxRetries: Int) async throws -> Data {
        try await fetchDataWithRetry(url: resource.url, byteRange: resource.byteRange, maxRetries: maxRetries)
    }

    private func decryptIfNeeded(
        data: Data,
        key: HLSEncryptionKey?,
        keyData: Data?,
        defaultSequenceNumber: UInt64?
    ) throws -> Data {
        guard let encKey = key else { return data }
        guard encKey.method == "AES-128", let keyBytes = keyData else {
            throw HLSError.unsupportedLayout(reason: "This HLS stream uses encryption that cannot be decrypted safely for offline playback.")
        }

        let iv: Data
        if let explicitIV = encKey.iv {
            iv = explicitIV
        } else {
            guard let defaultSequenceNumber else {
                throw HLSError.unsupportedLayout(reason: "This encrypted HLS initialization section is missing its required explicit IV.")
            }
            iv = HLSDownloadCompatibility.defaultAES128IV(sequenceNumber: defaultSequenceNumber)
        }

        return try aes128Decrypt(data: data, key: keyBytes, iv: iv)
    }

    static func resumeManifestFingerprint(
        _ content: String,
        playlistURL: URL,
        keyData: Data?,
        canonicalURL: (URL) -> URL? = { $0 }
    ) -> String? {
        guard content.utf8.count <= maximumPlaylistBytes,
              content.components(separatedBy: .newlines).contains(where: {
                  $0.trimmingCharacters(in: .whitespaces) == "#EXT-X-ENDLIST"
              }),
              let canonicalPlaylist = canonicalURL(playlistURL),
              let uriPattern = try? NSRegularExpression(pattern: #"(?i)(?:^|,)URI=(?:"([^"]*)"|([^,\s]*))"#) else { return nil }
        var hash = SHA256()
        hash.update(data: Data((canonicalPlaylist.absoluteString + "\n").utf8))
        if let keyData { hash.update(data: keyData) }
        hash.update(data: Data([0]))
        for rawLine in content.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if !line.hasPrefix("#") {
                guard let url = URL(string: line, relativeTo: playlistURL)?.absoluteURL,
                      let canonical = canonicalURL(url) else { return nil }
                line = canonical.absoluteString
            } else if let colon = line.firstIndex(of: ":") {
                let attributes = String(line[line.index(after: colon)...])
                let fullRange = NSRange(attributes.startIndex..., in: attributes)
                if let match = uriPattern.firstMatch(in: attributes, range: fullRange) {
                    let uriRange = match.range(at: match.range(at: 1).location == NSNotFound ? 2 : 1)
                    guard let range = Range(uriRange, in: attributes),
                          let url = URL(string: String(attributes[range]), relativeTo: playlistURL)?.absoluteURL,
                          let canonical = canonicalURL(url) else { return nil }
                    var updated = attributes
                    updated.replaceSubrange(range, with: canonical.absoluteString)
                    line = String(line[...colon]) + updated
                }
            }
            hash.update(data: Data((line + "\n").utf8))
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func isValidResumePosition(segment: Int, totalSegments: Int, expectedTotalSegments: Int) -> Bool {
        segment >= 0 && segment <= totalSegments
            && (segment == 0 || expectedTotalSegments == 0 || totalSegments == expectedTotalSegments)
    }

    static func isValidAES128Material(key: Data, iv: Data) -> Bool {
        key.count == kCCKeySizeAES128 && iv.count == kCCBlockSizeAES128
    }

    private func aes128Decrypt(data: Data, key: Data, iv: Data) throws -> Data {
        guard Self.isValidAES128Material(key: key, iv: iv) else {
            throw HLSError.decryptionFailed(status: Int(kCCParamError))
        }
        let keyLength = kCCKeySizeAES128
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, keyLength,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            bufferPtr.baseAddress, bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw HLSError.decryptionFailed(status: Int(status))
        }

        return buffer.prefix(numBytesDecrypted)
    }

    private func parseAttribute(_ attributes: String, key: String) -> String? {

        let pattern = "\(key)=(?:\"([^\"]*)\"|([^,\\s]*))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        let range = NSRange(attributes.startIndex..., in: attributes)
        guard let match = regex.firstMatch(in: attributes, range: range) else { return nil }

        if match.range(at: 1).location != NSNotFound,
           let valueRange = Range(match.range(at: 1), in: attributes) {
            return String(attributes[valueRange])
        }
        if match.range(at: 2).location != NSNotFound,
           let valueRange = Range(match.range(at: 2), in: attributes) {
            return String(attributes[valueRange])
        }

        return nil
    }

    private func resolveURL(_ urlString: String, baseURL: URL) -> URL? {
        guard let url = URL(string: urlString, relativeTo: baseURL)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil else { return nil }
        return url
    }

    private func checkCancelled() throws {
        if Task.isCancelled {
            throw currentCancellationError()
        }

        stateLock.lock()
        let cancelled = isCancelled
        let error = cancellationError
        stateLock.unlock()

        if cancelled {
            throw error
        }
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let hlsError = error as? HLSError {
            switch hlsError {
            case .cancelled, .backgroundTimeExpired, .backgroundProcessingExpired:
                return true
            default:
                return false
            }
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func currentCancellationError() -> HLSError {
        stateLock.lock()
        let error = cancellationError
        stateLock.unlock()
        return error
    }

    private func isResumableInterruption(_ error: Error) -> Bool {
        if let hlsError = error as? HLSError {
            switch hlsError {
            case .cancelled, .backgroundTimeExpired, .backgroundProcessingExpired, .systemBackoff, .rateLimited:
                return true
            default:
                return false
            }
        }
        return isCancellationError(error)
    }

    private static func fileSize(at url: URL) -> Int64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return 0 }
        return size
    }

    private func clearWorkerTask() {
        stateLock.lock()
        let retiresSession = isCancelled && !sessionRetired
        if retiresSession { sessionRetired = true }
        workerTask = nil
        stateLock.unlock()
        if retiresSession { session.invalidateAndCancel() }
    }

    private func finish(_ result: Result<URL, Error>) {
        stateLock.lock()
        guard !didFinish else {
            stateLock.unlock()
            return
        }
        didFinish = true
        stateLock.unlock()

        onCompletion?(result)
    }

    private func checkSystemBackoff() throws {
        #if canImport(UIKit) || os(macOS)
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .serious || thermalState == .critical {
            throw HLSError.systemBackoff(reason: "Paused for thermal state")
        }
        #endif
    }

    private func ensureDiskCapacity(additionalBytes: Int64 = 0) throws {
        guard enforcesConservativeDiskCapacityReserve else { return }
        let directory = destinationURL.deletingLastPathComponent()
        guard let values = try? directory.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) else {
            throw HLSError.systemBackoff(reason: "Waiting for disk capacity check")
        }
        let available = values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map(Int64.init)
        guard let available,
              additionalBytes >= 0,
              available >= Self.minimumFreeCapacityReserve + additionalBytes else {
            throw HLSError.systemBackoff(reason: "Paused for low disk space")
        }
    }

    private func hexStringToData(_ hex: String) -> Data? {
        var hexStr = hex
        if hexStr.hasPrefix("0x") || hexStr.hasPrefix("0X") {
            hexStr = String(hexStr.dropFirst(2))
        }

        var data = Data()
        var i = hexStr.startIndex
        while i < hexStr.endIndex {
            guard let next = hexStr.index(i, offsetBy: 2, limitedBy: hexStr.endIndex) else { break }
            let byteString = hexStr[i..<next]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            i = next
        }

        return data
    }
}

enum HLSError: LocalizedError {
    case noVariantsFound
    case noSegmentsFound
    case resumePlaylistChanged
    case resumeCheckpointMissing
    case invalidPlaylistData
    case unsupportedLayout(reason: String)
    case httpError(statusCode: Int)
    case rateLimited(retryAfterSeconds: TimeInterval?)
    case decryptionFailed(status: Int)
    case cloudflareVerificationRequired(url: URL, rejectedCookieHeader: String?)
    case cancelled
    case backgroundTimeExpired
    case backgroundProcessingExpired
    case couldNotCreateOutput
    case systemBackoff(reason: String)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .noVariantsFound:
            return "No video variants found in HLS playlist"
        case .noSegmentsFound:
            return "No segments found in HLS media playlist"
        case .resumePlaylistChanged:
            return "The source could not verify resuming the same HLS playlist. Saved progress was kept; remove this download and select it again to restart."
        case .resumeCheckpointMissing:
            return "The saved HLS checkpoint is missing or incomplete. Remove this download and select it again to restart."
        case .unsupportedLayout(let reason):
            return reason
        case .invalidPlaylistData:
            return "Could not read HLS playlist data"
        case .httpError(let code):
            return "HTTP error \(code) while downloading HLS content"
        case .rateLimited(let retryAfterSeconds):
            if let retryAfterSeconds,
               retryAfterSeconds.isFinite,
               retryAfterSeconds >= 0,
               let displaySeconds = Int(exactly: ceil(retryAfterSeconds)) {
                return "HLS source rate limited requests (retry after \(displaySeconds) seconds)"
            }
            return "HLS source rate limited requests"
        case .decryptionFailed(let status):
            return "AES-128 decryption failed (status: \(status))"
        case .cloudflareVerificationRequired:
            return "Cloudflare verification required. Open the source once and try again."
        case .cancelled:
            return "Download was cancelled"
        case .backgroundTimeExpired:
            return "HLS download paused after iOS background time expired"
        case .backgroundProcessingExpired:
            return "HLS download paused after background processing ended"
        case .couldNotCreateOutput:
            return "Could not create HLS output file"
        case .systemBackoff(let reason):
            return reason
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

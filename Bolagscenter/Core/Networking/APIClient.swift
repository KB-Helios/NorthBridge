import Foundation

enum HTTPMethod: String, Codable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum APICachePolicy: Equatable, Sendable {
    case reloadIgnoringCache
    case revalidateWithETag
    case returnCacheElseLoad(maxAge: Duration)
}

struct APIRequest<Response: Decodable & Sendable>: Sendable {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data?
    let cachePolicy: APICachePolicy
    let requiresAuthentication: Bool
    let idempotencyKey: String?
    let expectedETag: String?
    let queuesWhenOffline: Bool

    init(
        method: HTTPMethod = .get,
        path: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        cachePolicy: APICachePolicy = .revalidateWithETag,
        requiresAuthentication: Bool = true,
        idempotencyKey: String? = nil,
        expectedETag: String? = nil,
        queuesWhenOffline: Bool = false
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.cachePolicy = cachePolicy
        self.requiresAuthentication = requiresAuthentication
        self.idempotencyKey = idempotencyKey
            ?? (method == .get ? nil : UUID().uuidString)
        self.expectedETag = expectedETag
        self.queuesWhenOffline = queuesWhenOffline
    }
}

struct PaginatedResponse<Value: Decodable & Sendable>: Decodable, Sendable {
    let items: [Value]
    let nextCursor: String?
}

protocol AccessTokenProvider: Sendable {
    func accessToken() async throws -> String?
    func refreshAccessToken() async throws -> String
}

struct NoAccessTokenProvider: AccessTokenProvider {
    func accessToken() async throws -> String? { nil }

    func refreshAccessToken() async throws -> String {
        throw APIClientError.authenticationRequired
    }
}

enum APIClientError: LocalizedError, Equatable, Sendable {
    case invalidBaseURL
    case invalidRequestURL
    case invalidResponse
    case authenticationRequired
    case forbidden
    case notFound
    case conflict(serverVersion: String?)
    case preconditionFailed(currentETag: String?)
    case rateLimited(retryAfter: Duration?)
    case server(statusCode: Int, requestID: String?)
    case decoding
    case offline
    case timedOut
    case cancelled
    case transport
    case queuedForRetry(id: UUID)
    case retryQueueUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Backendadressen är inte konfigurerad."
        case .invalidRequestURL:
            "Anropet kunde inte skapas."
        case .invalidResponse:
            "Tjänsten returnerade ett ogiltigt svar."
        case .authenticationRequired:
            "Sessionen har gått ut. Logga in igen."
        case .forbidden:
            "Du saknar behörighet för åtgärden."
        case .notFound:
            "Den begärda posten finns inte."
        case .conflict:
            "Posten har ändrats på en annan enhet. Granska båda versionerna innan du väljer vad som ska sparas."
        case .preconditionFailed:
            "Underlaget är inaktuellt. Hämta den senaste versionen och försök igen."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "Tjänsten är tillfälligt begränsad. Försök igen om \(retryAfter.components.seconds) sekunder."
            } else {
                "Tjänsten är tillfälligt begränsad. Försök igen senare."
            }
        case .server(_, let requestID):
            if let requestID {
                "Tjänsten kunde inte slutföra anropet. Referens: \(requestID)"
            } else {
                "Tjänsten kunde inte slutföra anropet."
            }
        case .decoding:
            "Svaret hade ett format som appen inte kunde läsa."
        case .offline:
            "Ingen nätverksanslutning. Lokal data visas med sin senaste uppdateringstid."
        case .timedOut:
            "Anropet tog för lång tid. Försök igen."
        case .cancelled:
            "Anropet avbröts."
        case .transport:
            "Ett nätverksfel inträffade."
        case .queuedForRetry:
            "Ingen nätverksanslutning. Ändringen sparades i den skyddade kön och försöks igen senare."
        case .retryQueueUnavailable:
            "Ändringen kunde inte sparas i den lokala synkroniseringskön."
        }
    }
}

actor HTTPClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: any AccessTokenProvider
    private let cache = ETagResponseCache()
    private let decoder: JSONDecoder
    private let maximumRetryCount: Int
    private let mutationQueue: OfflineMutationQueue?

    init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: any AccessTokenProvider = NoAccessTokenProvider(),
        maximumRetryCount: Int = 2,
        mutationQueue: OfflineMutationQueue? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.maximumRetryCount = maximumRetryCount
        self.mutationQueue = mutationQueue
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func send<Response: Decodable & Sendable>(
        _ request: APIRequest<Response>
    ) async throws -> Response {
        do {
            let data = try await loadData(
                request,
                attempt: 0,
                hasRefreshedToken: false
            )
            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                SecureLogger.network.error(
                    "Response decoding failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
                )
                throw APIClientError.decoding
            }
        } catch is CancellationError {
            throw APIClientError.cancelled
        } catch let error as APIClientError {
            throw error
        } catch let error as URLError {
            let mappedError = map(error)
            if mappedError == .offline,
               request.method != .get,
               request.queuesWhenOffline,
               let mutationQueue {
                do {
                    let queuedID = try await mutationQueue.enqueue(request)
                    throw APIClientError.queuedForRetry(id: queuedID)
                } catch let error as APIClientError {
                    throw error
                } catch {
                    throw APIClientError.retryQueueUnavailable
                }
            }
            throw mappedError
        } catch {
            throw APIClientError.transport
        }
    }

    func replayQueuedMutations() async throws {
        guard let mutationQueue else { return }
        try await mutationQueue.drain { [self] mutation in
            try await replay(mutation)
        }
    }

    private func replay(_ mutation: QueuedMutation) async throws {
        let request = APIRequest<OfflineReplayResponse>(
            method: mutation.method,
            path: mutation.path,
            queryItems: mutation.queryItems.map {
                URLQueryItem(name: $0.name, value: $0.value)
            },
            headers: mutation.headers,
            body: mutation.body,
            cachePolicy: .reloadIgnoringCache,
            requiresAuthentication: mutation.requiresAuthentication,
            idempotencyKey: mutation.idempotencyKey,
            expectedETag: mutation.expectedETag,
            queuesWhenOffline: false
        )
        do {
            _ = try await loadData(
                request,
                attempt: 0,
                hasRefreshedToken: false
            )
        } catch is CancellationError {
            throw APIClientError.cancelled
        } catch let error as APIClientError {
            throw error
        } catch let error as URLError {
            throw map(error)
        } catch {
            throw APIClientError.transport
        }
    }

    private func loadData<Response: Decodable & Sendable>(
        _ request: APIRequest<Response>,
        attempt: Int,
        hasRefreshedToken: Bool
    ) async throws -> Data {
        try Task.checkCancellation()
        let url = try makeURL(path: request.path, queryItems: request.queryItems)
        let cacheKey = "\(request.method.rawValue):\(url.absoluteString)"

        if case .returnCacheElseLoad(let maxAge) = request.cachePolicy,
           let cached = await cache.freshValue(for: cacheKey, maxAge: maxAge) {
            return cached.data
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = 30
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        if let idempotencyKey = request.idempotencyKey {
            urlRequest.setValue(
                idempotencyKey,
                forHTTPHeaderField: "Idempotency-Key"
            )
        }
        if let expectedETag = request.expectedETag {
            urlRequest.setValue(expectedETag, forHTTPHeaderField: "If-Match")
        }
        if request.requiresAuthentication {
            guard let accessToken = try await tokenProvider.accessToken(),
                  !accessToken.isEmpty else {
                throw APIClientError.authenticationRequired
            }
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if request.cachePolicy != .reloadIgnoringCache,
           let cached = await cache.value(for: cacheKey),
           let etag = cached.etag {
            urlRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        let requestID = httpResponse.value(forHTTPHeaderField: "X-Request-ID")

        if httpResponse.statusCode == 304,
           let cached = await cache.value(for: cacheKey) {
            await cache.touch(cacheKey)
            return cached.data
        }

        if (200..<300).contains(httpResponse.statusCode) {
            if request.method == .get {
                await cache.store(
                    data: data,
                    etag: httpResponse.value(forHTTPHeaderField: "ETag"),
                    for: cacheKey
                )
            }
            return data
        }

        if httpResponse.statusCode == 401,
           request.requiresAuthentication,
           !hasRefreshedToken {
            _ = try await tokenProvider.refreshAccessToken()
            return try await loadData(
                request,
                attempt: attempt,
                hasRefreshedToken: true
            )
        }

        if httpResponse.statusCode == 429 {
            let retryAfter = retryDuration(from: httpResponse)
            guard attempt < maximumRetryCount else {
                throw APIClientError.rateLimited(retryAfter: retryAfter)
            }
            try await Task.sleep(for: retryAfter ?? backoff(for: attempt))
            return try await loadData(
                request,
                attempt: attempt + 1,
                hasRefreshedToken: hasRefreshedToken
            )
        }

        if (500..<600).contains(httpResponse.statusCode), attempt < maximumRetryCount {
            try await Task.sleep(for: backoff(for: attempt))
            return try await loadData(
                request,
                attempt: attempt + 1,
                hasRefreshedToken: hasRefreshedToken
            )
        }

        switch httpResponse.statusCode {
        case 401:
            throw APIClientError.authenticationRequired
        case 403:
            throw APIClientError.forbidden
        case 404:
            throw APIClientError.notFound
        case 409:
            throw APIClientError.conflict(
                serverVersion: httpResponse.value(
                    forHTTPHeaderField: "X-Resource-Version"
                )
            )
        case 412:
            throw APIClientError.preconditionFailed(
                currentETag: httpResponse.value(
                    forHTTPHeaderField: "ETag"
                )
            )
        default:
            throw APIClientError.server(
                statusCode: httpResponse.statusCode,
                requestID: requestID
            )
        }
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let endpoint = baseURL.appending(path: normalizedPath)
        guard var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        ) else {
            throw APIClientError.invalidRequestURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url, url.scheme == "https" else {
            throw APIClientError.invalidRequestURL
        }
        return url
    }

    private func retryDuration(from response: HTTPURLResponse) -> Duration? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = Int64(value),
              seconds >= 0 else {
            return nil
        }
        return .seconds(min(seconds, 60))
    }

    private func backoff(for attempt: Int) -> Duration {
        .milliseconds(350 * (1 << min(attempt, 4)))
    }

    private func map(_ error: URLError) -> APIClientError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            .offline
        case .timedOut:
            .timedOut
        case .cancelled:
            .cancelled
        default:
            .transport
        }
    }
}

private struct OfflineReplayResponse: Decodable, Sendable {}

private actor ETagResponseCache {
    struct Entry: Sendable {
        let data: Data
        let etag: String?
        var storedAt: ContinuousClock.Instant
    }

    private var values: [String: Entry] = [:]
    private let clock = ContinuousClock()

    func value(for key: String) -> Entry? {
        values[key]
    }

    func freshValue(for key: String, maxAge: Duration) -> Entry? {
        guard let entry = values[key],
              entry.storedAt.duration(to: clock.now) <= maxAge else {
            return nil
        }
        return entry
    }

    func store(data: Data, etag: String?, for key: String) {
        values[key] = Entry(data: data, etag: etag, storedAt: clock.now)
    }

    func touch(_ key: String) {
        guard var entry = values[key] else { return }
        entry.storedAt = clock.now
        values[key] = entry
    }
}

import Foundation
import Testing
@testable import Bolagscenter

@Suite(.serialized)
struct HTTPClientTests {
    struct Response: Decodable, Sendable {
        let value: String
    }

    @Test
    func decodesTypedSuccessfulResponse() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        MockURLProtocol.handler = { request in
            let response = try #require(
                HTTPURLResponse(
                    url: request.url ?? baseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["ETag": "\"v1\""]
                )
            )
            return (response, Data(#"{"value":"ok"}"#.utf8))
        }
        defer { MockURLProtocol.handler = nil }

        let client = HTTPClient(
            baseURL: baseURL,
            session: makeSession(),
            maximumRetryCount: 0
        )
        let response: Response = try await client.send(
            APIRequest(path: "/v1/test", requiresAuthentication: false)
        )

        #expect(response.value == "ok")
    }

    @Test
    func mapsForbiddenResponseToTypedError() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        MockURLProtocol.handler = { request in
            let response = try #require(
                HTTPURLResponse(
                    url: request.url ?? baseURL,
                    statusCode: 403,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, Data())
        }
        defer { MockURLProtocol.handler = nil }

        let client = HTTPClient(
            baseURL: baseURL,
            session: makeSession(),
            maximumRetryCount: 0
        )

        await #expect(throws: APIClientError.forbidden) {
            let _: Response = try await client.send(
                APIRequest(path: "/v1/protected", requiresAuthentication: false)
            )
        }
    }

    @Test
    func rejectsProtectedRequestLocallyWithoutAccessToken() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        let client = HTTPClient(
            baseURL: baseURL,
            session: makeSession(),
            maximumRetryCount: 0
        )

        await #expect(throws: APIClientError.authenticationRequired) {
            let _: Response = try await client.send(
                APIRequest(path: "/v1/protected")
            )
        }
    }

    @Test
    func refreshesAccessTokenOnceAndRetriesUnauthorizedRequest() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        let tokenProvider = RotatingTokenProvider()
        MockURLProtocol.handler = { request in
            let authorization = request.value(
                forHTTPHeaderField: "Authorization"
            )
            let statusCode = authorization == "Bearer fresh-token" ? 200 : 401
            let response = try #require(
                HTTPURLResponse(
                    url: request.url ?? baseURL,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            let data = statusCode == 200
                ? Data(#"{"value":"authorized"}"#.utf8)
                : Data()
            return (response, data)
        }
        defer { MockURLProtocol.handler = nil }

        let client = HTTPClient(
            baseURL: baseURL,
            session: makeSession(),
            tokenProvider: tokenProvider,
            maximumRetryCount: 0
        )
        let response: Response = try await client.send(
            APIRequest(path: "/v1/protected")
        )
        let refreshCount = await tokenProvider.refreshCount()

        #expect(response.value == "authorized")
        #expect(refreshCount == 1)
    }

    @Test
    func sendsMutationConcurrencyHeaders() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        let idempotencyKey = UUID().uuidString
        MockURLProtocol.handler = { request in
            #expect(
                request.value(
                    forHTTPHeaderField: "Idempotency-Key"
                ) == idempotencyKey
            )
            #expect(
                request.value(forHTTPHeaderField: "If-Match")
                    == #""revision-4""#
            )
            let response = try #require(
                HTTPURLResponse(
                    url: request.url ?? baseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, Data(#"{"value":"updated"}"#.utf8))
        }
        defer { MockURLProtocol.handler = nil }

        let client = HTTPClient(
            baseURL: baseURL,
            session: makeSession(),
            maximumRetryCount: 0
        )
        let response: Response = try await client.send(
            APIRequest(
                method: .patch,
                path: "/v1/resource",
                body: Data(#"{"name":"updated"}"#.utf8),
                requiresAuthentication: false,
                idempotencyKey: idempotencyKey,
                expectedETag: #""revision-4""#
            )
        )

        #expect(response.value == "updated")
    }

    @Test
    func replaysProtectedOfflineMutationWithOriginalIdempotencyKey() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        let queueURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "offline-mutations.json")
        defer {
            try? FileManager.default.removeItem(
                at: queueURL.deletingLastPathComponent()
            )
        }
        let queue = OfflineMutationQueue(fileURL: queueURL)
        let queuedRequest = APIRequest<Response>(
            method: .post,
            path: "/v1/actions",
            body: Data(#"{"title":"Queued"}"#.utf8),
            idempotencyKey: "stable-replay-key",
            queuesWhenOffline: true
        )
        _ = try await queue.enqueue(queuedRequest)

        MockURLProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(
                request.value(forHTTPHeaderField: "Idempotency-Key")
                    == "stable-replay-key"
            )
            #expect(
                request.value(forHTTPHeaderField: "Authorization")
                    == "Bearer test-access-token"
            )
            let response = try #require(
                HTTPURLResponse(
                    url: request.url ?? baseURL,
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, Data())
        }
        defer { MockURLProtocol.handler = nil }

        let client = HTTPClient(
            baseURL: baseURL,
            session: makeSession(),
            tokenProvider: StaticTokenProvider(),
            maximumRetryCount: 0,
            mutationQueue: queue
        )
        try await client.replayQueuedMutations()
        let remaining = try await queue.all()

        #expect(remaining.isEmpty)
    }

    @Test
    func mapsConflictWithServerVersion() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        MockURLProtocol.handler = { request in
            let response = try #require(
                HTTPURLResponse(
                    url: request.url ?? baseURL,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: ["X-Resource-Version": "revision-5"]
                )
            )
            return (response, Data())
        }
        defer { MockURLProtocol.handler = nil }

        let client = HTTPClient(
            baseURL: baseURL,
            session: makeSession(),
            maximumRetryCount: 0
        )

        await #expect(
            throws: APIClientError.conflict(
                serverVersion: "revision-5"
            )
        ) {
            let _: Response = try await client.send(
                APIRequest(
                    method: .patch,
                    path: "/v1/resource",
                    requiresAuthentication: false
                )
            )
        }
    }

    @Test
    func companyRegistryAdapterMapsBackendResponse() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        MockURLProtocol.handler = { request in
            #expect(
                request.url?.path
                    == "/v1/companies/5560160680"
            )
            let response = try #require(
                HTTPURLResponse(
                    url: request.url ?? baseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            let data = Data(
                #"""
                {
                  "organisationNumber": "5560160680",
                  "registeredName": "Nordisk Test AB",
                  "status": "active",
                  "registeredOffice": "Stockholm",
                  "sourceName": "Testregister",
                  "sourceUpdatedAt": "2026-07-31T08:00:00Z"
                }
                """#.utf8
            )
            return (response, data)
        }
        defer { MockURLProtocol.handler = nil }

        let client = HTTPClient(
            baseURL: baseURL,
            session: makeSession(),
            maximumRetryCount: 0
        )
        let service = BackendCompanyRegistryService(client: client)
        let company = try await service.fetchCompanyDetails(
            organisationNumber: OrganisationNumber("5560160680")
        )

        #expect(company.organisationNumber.digits == "5560160680")
        #expect(company.registeredName == "Nordisk Test AB")
        #expect(company.status == .active)
        #expect(company.registeredOffice == "Stockholm")
        #expect(company.sourceName == "Testregister")
    }

    @Test
    func unavailableRegistryAdapterNeverFabricatesCompanyData() async throws {
        let service = UnavailableCompanyRegistryService(
            providerName: "Bolagsverket"
        )

        await #expect(
            throws: IntegrationAdapterError.notConfigured(
                provider: "Bolagsverket"
            )
        ) {
            _ = try await service.searchCompany(
                organisationNumber: OrganisationNumber("5560160680")
            )
        }
    }

    @Test
    func remoteNotificationAdapterForwardsCurrentTokenWithoutOfflineCaching() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        MockURLProtocol.handler = { request in
            #expect(request.httpMethod == "PUT")
            #expect(
                request.url?.path
                    == "/v1/notification-installations/test-installation"
            )
            let requestBody = try request.bodyDataForTesting()
            let body = try #require(requestBody)
            let payload = try #require(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            #expect(payload["apns_token"] as? String == "000a10ff")
            #expect(payload["apns_environment"] as? String == "sandbox")
            #expect(payload["authorization"] as? String == "authorized")
            #expect(payload["shows_sensitive_details"] as? Bool == false)

            let response = try #require(
                HTTPURLResponse(
                    url: request.url ?? baseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            let data = Data(
                #"""
                {
                  "installation_id": "test-installation",
                  "registered_at": "2026-07-31T08:00:00Z",
                  "status": "active"
                }
                """#.utf8
            )
            return (response, data)
        }
        defer { MockURLProtocol.handler = nil }

        let client = HTTPClient(
            baseURL: baseURL,
            session: makeSession(),
            tokenProvider: StaticTokenProvider(),
            maximumRetryCount: 0
        )
        let service = BackendRemoteNotificationRegistrationService(client: client)
        let receipt = try await service.register(
            APNsTokenSnapshot(
                installationID: "test-installation",
                token: "000a10ff",
                environment: .sandbox,
                authorization: .authorized,
                receivedAt: Date(timeIntervalSince1970: 1_750_000_000),
                appVersion: "0.1.0",
                locale: "sv-SE"
            )
        )

        #expect(receipt.installationID == "test-installation")
        #expect(receipt.status == "active")
    }

    @Test
    func remoteNotificationAdapterUnregistersInstallationExplicitly() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        MockURLProtocol.handler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(
                request.url?.path
                    == "/v1/notification-installations/test-installation"
            )
            let response = try #require(
                HTTPURLResponse(
                    url: request.url ?? baseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            let data = Data(
                #"""
                {
                  "installation_id": "test-installation",
                  "registered_at": "2026-07-31T08:00:00Z",
                  "status": "removed"
                }
                """#.utf8
            )
            return (response, data)
        }
        defer { MockURLProtocol.handler = nil }

        let client = HTTPClient(
            baseURL: baseURL,
            session: makeSession(),
            tokenProvider: StaticTokenProvider(),
            maximumRetryCount: 0
        )
        let service = BackendRemoteNotificationRegistrationService(client: client)

        try await service.unregister(installationID: "test-installation")
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private extension URLRequest {
    func bodyDataForTesting() throws -> Data? {
        if let httpBody {
            return httpBody
        }
        guard let stream = httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count == 0 {
                return data
            }
            if count < 0 {
                throw stream.streamError
                    ?? URLError(.cannotDecodeContentData)
            }
            data.append(buffer, count: count)
        }
    }
}

private actor RotatingTokenProvider: AccessTokenProvider {
    private var token = "expired-token"
    private var numberOfRefreshes = 0

    func accessToken() async throws -> String? {
        token
    }

    func refreshAccessToken() async throws -> String {
        numberOfRefreshes += 1
        token = "fresh-token"
        return token
    }

    func refreshCount() -> Int {
        numberOfRefreshes
    }
}

private struct StaticTokenProvider: AccessTokenProvider {
    func accessToken() async throws -> String? {
        "test-access-token"
    }

    func refreshAccessToken() async throws -> String {
        "test-access-token"
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

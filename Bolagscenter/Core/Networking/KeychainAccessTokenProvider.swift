import Foundation

private struct RefreshTokenRequest: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct RefreshTokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

actor KeychainAccessTokenProvider: AccessTokenProvider {
    private static let accessTokenKey = "authentication.accessToken"
    private static let refreshTokenKey = "authentication.refreshToken"

    private let keychain: KeychainStore
    private let baseURL: URL
    private let session: URLSession

    init(
        keychain: KeychainStore,
        baseURL: URL,
        session: URLSession = .shared
    ) {
        self.keychain = keychain
        self.baseURL = baseURL
        self.session = session
    }

    func accessToken() async throws -> String? {
        guard let data = try await keychain.data(for: Self.accessTokenKey) else {
            return nil
        }
        guard let token = String(data: data, encoding: .utf8), !token.isEmpty else {
            throw APIClientError.authenticationRequired
        }
        return token
    }

    func refreshAccessToken() async throws -> String {
        guard let refreshData = try await keychain.data(
            for: Self.refreshTokenKey
        ),
              let refreshToken = String(data: refreshData, encoding: .utf8),
              !refreshToken.isEmpty else {
            throw APIClientError.authenticationRequired
        }

        let endpoint = baseURL.appending(path: "v1/auth/sessions/refresh")
        guard endpoint.scheme == "https" else {
            throw APIClientError.invalidRequestURL
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = HTTPMethod.post.rawValue
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try JSONEncoder().encode(
            RefreshTokenRequest(refreshToken: refreshToken)
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIClientError.authenticationRequired
            }
            throw APIClientError.server(
                statusCode: httpResponse.statusCode,
                requestID: httpResponse.value(
                    forHTTPHeaderField: "X-Request-ID"
                )
            )
        }

        let payload: RefreshTokenResponse
        do {
            payload = try JSONDecoder().decode(
                RefreshTokenResponse.self,
                from: data
            )
        } catch {
            throw APIClientError.decoding
        }
        guard !payload.accessToken.isEmpty else {
            throw APIClientError.decoding
        }

        try await keychain.store(
            Data(payload.accessToken.utf8),
            for: Self.accessTokenKey
        )
        if let rotatedRefreshToken = payload.refreshToken,
           !rotatedRefreshToken.isEmpty {
            try await keychain.store(
                Data(rotatedRefreshToken.utf8),
                for: Self.refreshTokenKey
            )
        }
        return payload.accessToken
    }
}

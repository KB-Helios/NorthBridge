import Foundation
import LocalAuthentication
import Observation

struct SecureSession: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable {
        case localDevice
        case backend
    }

    let id: UUID
    let accountID: UUID
    let issuedAt: Date
    let expiresAt: Date
    let source: Source
}

struct SessionExpirationPolicy: Sendable {
    func isExpired(_ session: SecureSession, now: Date = .now) -> Bool {
        session.expiresAt <= now
    }
}

enum SessionState: Equatable, Sendable {
    case checking
    case signedOut
    case active(SecureSession)
    case expired
}

enum SessionError: LocalizedError {
    case authenticationUnavailable
    case authenticationFailed
    case invalidStoredSession

    var errorDescription: String? {
        switch self {
        case .authenticationUnavailable:
            "Enhetsautentisering är inte tillgänglig."
        case .authenticationFailed:
            "Inloggningen avbröts eller kunde inte genomföras."
        case .invalidStoredSession:
            "Den sparade sessionen kunde inte verifieras. Logga in igen."
        }
    }
}

@MainActor
@Observable
final class SessionController {
    private static let sessionKey = "authentication.session.v1"
    private static let localSessionDuration: TimeInterval = 12 * 60 * 60

    private(set) var state: SessionState = .checking
    private(set) var errorMessage: String?
    private let keychain: KeychainStore
    private let expirationPolicy = SessionExpirationPolicy()

    init(keychain: KeychainStore) {
        self.keychain = keychain
    }

    var activeSession: SecureSession? {
        guard case .active(let session) = state else { return nil }
        return session
    }

    func restore() async {
        guard state == .checking else {
            await validateExpiration()
            return
        }
        do {
            guard let data = try await keychain.data(for: Self.sessionKey) else {
                state = .signedOut
                return
            }
            let session = try JSONDecoder().decode(SecureSession.self, from: data)
            guard !expirationPolicy.isExpired(session) else {
                await deleteStoredAuthentication()
                state = .expired
                return
            }
            state = .active(session)
        } catch {
            try? await keychain.delete(Self.sessionKey)
            state = .signedOut
            errorMessage = SessionError.invalidStoredSession.localizedDescription
            SecureLogger.security.error(
                "Stored session rejected: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }

    func createLocalSession(accountID: UUID) async throws {
        let session = SecureSession(
            id: UUID(),
            accountID: accountID,
            issuedAt: .now,
            expiresAt: .now.addingTimeInterval(Self.localSessionDuration),
            source: .localDevice
        )
        try await persist(session)
    }

    #if DEBUG
    func installUITestExpiredState() {
        state = .expired
        errorMessage = nil
    }
    #endif

    func signInLocally(accountID: UUID) async {
        errorMessage = nil
        do {
            try await confirmIdentity(
                reason: String(localized: "Logga in säkert i NorthBridge")
            )
            try await createLocalSession(accountID: accountID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmIdentity(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Avbryt")
        var policyError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: &policyError
        ) else {
            throw SessionError.authenticationUnavailable
        }

        do {
            let authenticated = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            guard authenticated else {
                throw SessionError.authenticationFailed
            }
        } catch let error as SessionError {
            throw error
        } catch {
            throw SessionError.authenticationFailed
        }
    }

    func validateExpiration(now: Date = .now) async {
        guard case .active(let session) = state else { return }
        guard expirationPolicy.isExpired(session, now: now) else { return }
        await deleteStoredAuthentication()
        state = .expired
    }

    func logout() async {
        await deleteStoredAuthentication()
        state = .signedOut
        errorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private func persist(_ session: SecureSession) async throws {
        let data = try JSONEncoder().encode(session)
        try await keychain.store(data, for: Self.sessionKey)
        state = .active(session)
        errorMessage = nil
    }

    private func deleteStoredAuthentication() async {
        for key in [
            Self.sessionKey,
            "authentication.accessToken",
            "authentication.refreshToken"
        ] {
            do {
                try await keychain.delete(key)
            } catch {
                SecureLogger.security.error(
                    "Keychain authentication cleanup failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
                )
            }
        }
    }
}

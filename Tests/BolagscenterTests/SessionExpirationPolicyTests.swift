import Foundation
import Testing
@testable import Bolagscenter

struct SessionExpirationPolicyTests {
    private let policy = SessionExpirationPolicy()

    @Test
    func sessionRemainsActiveBeforeExpiration() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = SecureSession(
            id: UUID(),
            accountID: UUID(),
            issuedAt: now.addingTimeInterval(-100),
            expiresAt: now.addingTimeInterval(1),
            source: .localDevice
        )

        #expect(!policy.isExpired(session, now: now))
    }

    @Test
    func sessionExpiresAtBoundary() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = SecureSession(
            id: UUID(),
            accountID: UUID(),
            issuedAt: now.addingTimeInterval(-100),
            expiresAt: now,
            source: .backend
        )

        #expect(policy.isExpired(session, now: now))
    }
}

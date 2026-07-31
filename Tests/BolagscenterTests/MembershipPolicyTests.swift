import Foundation
import Testing
@testable import Bolagscenter

struct MembershipPolicyTests {
    private let policy = MembershipPolicy()

    @Test
    func cannotDeactivateLastManager() {
        let membership = MembershipSnapshot(
            id: UUID(),
            accountID: UUID(),
            role: .owner,
            isActive: true
        )

        #expect(throws: MembershipPolicyError.lastManager) {
            try policy.validateChange(
                membershipID: membership.id,
                newRole: .owner,
                willRemainActive: false,
                memberships: [membership]
            )
        }
    }

    @Test
    func canDemoteManagerWhenAnotherManagerRemains() throws {
        let target = MembershipSnapshot(
            id: UUID(),
            accountID: UUID(),
            role: .owner,
            isActive: true
        )
        let other = MembershipSnapshot(
            id: UUID(),
            accountID: UUID(),
            role: .administrator,
            isActive: true
        )

        try policy.validateChange(
            membershipID: target.id,
            newRole: .boardMember,
            willRemainActive: true,
            memberships: [target, other]
        )
    }

    @Test
    func normalizesInvitationEmailForDuplicateCheck() {
        #expect(throws: MembershipPolicyError.duplicatePendingInvitation) {
            try policy.validateInvitation(
                email: "  USER@example.se ",
                pendingEmails: ["user@example.se"]
            )
        }
    }

    @Test
    func rejectsMalformedInvitationEmail() {
        #expect(throws: MembershipPolicyError.invalidEmail) {
            try policy.validateInvitation(
                email: "missing-domain@example",
                pendingEmails: []
            )
        }
    }
}

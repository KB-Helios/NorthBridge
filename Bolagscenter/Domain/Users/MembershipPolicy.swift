import Foundation

struct MembershipSnapshot: Equatable, Sendable {
    let id: UUID
    let accountID: UUID
    let role: CompanyRole
    let isActive: Bool
}

enum MembershipPolicyError: LocalizedError, Equatable, Sendable {
    case lastManager
    case duplicatePendingInvitation
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .lastManager:
            "Bolaget måste ha minst en aktiv ägare eller administratör."
        case .duplicatePendingInvitation:
            "Det finns redan en aktiv inbjudan till den e-postadressen."
        case .invalidEmail:
            "Ange en giltig e-postadress."
        }
    }
}

struct MembershipPolicy: Sendable {
    func validateChange(
        membershipID: UUID,
        newRole: CompanyRole,
        willRemainActive: Bool,
        memberships: [MembershipSnapshot]
    ) throws {
        guard let target = memberships.first(where: { $0.id == membershipID }) else {
            return
        }
        let targetWasManager = target.isActive && isManager(target.role)
        let targetWillBeManager = willRemainActive && isManager(newRole)
        guard targetWasManager && !targetWillBeManager else { return }

        let otherManagers = memberships.filter {
            $0.id != membershipID && $0.isActive && isManager($0.role)
        }
        guard !otherManagers.isEmpty else {
            throw MembershipPolicyError.lastManager
        }
    }

    func validateInvitation(
        email: String,
        pendingEmails: [String]
    ) throws {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalized.contains("@"),
              normalized.split(separator: "@").count == 2,
              normalized.split(separator: "@").last?.contains(".") == true else {
            throw MembershipPolicyError.invalidEmail
        }
        guard !pendingEmails.map({ $0.lowercased() }).contains(normalized) else {
            throw MembershipPolicyError.duplicatePendingInvitation
        }
    }

    private func isManager(_ role: CompanyRole) -> Bool {
        role == .owner || role == .administrator
    }
}

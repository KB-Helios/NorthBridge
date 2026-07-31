import Foundation

enum CompanyRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case owner
    case boardMember
    case chiefExecutive
    case administrator
    case accountingConsultant
    case auditor
    case readOnlyAdvisor

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .owner: "Ägare"
        case .boardMember: "Styrelseledamot"
        case .chiefExecutive: "VD"
        case .administrator: "Administratör"
        case .accountingConsultant: "Redovisningskonsult"
        case .auditor: "Revisor"
        case .readOnlyAdvisor: "Läsbehörig rådgivare"
        }
    }
}

enum CompanyPermission: String, Sendable {
    case viewCompany
    case editCompany
    case manageBoard
    case manageOwnership
    case manageDocuments
    case manageDeadlines
    case viewFinance
    case manageFinance
    case manageUsers
    case exportData
}

struct PermissionPolicy: Sendable {
    func allows(_ permission: CompanyPermission, for role: CompanyRole) -> Bool {
        switch role {
        case .owner, .administrator:
            true
        case .boardMember:
            [.viewCompany, .manageBoard, .manageDocuments, .manageDeadlines, .exportData].contains(permission)
        case .chiefExecutive:
            [.viewCompany, .editCompany, .manageBoard, .manageDocuments, .manageDeadlines, .viewFinance, .manageFinance, .exportData].contains(permission)
        case .accountingConsultant:
            [.viewCompany, .manageDocuments, .manageDeadlines, .viewFinance, .manageFinance, .exportData].contains(permission)
        case .auditor:
            [.viewCompany, .manageDocuments, .viewFinance, .exportData].contains(permission)
        case .readOnlyAdvisor:
            [.viewCompany, .viewFinance, .exportData].contains(permission)
        }
    }
}

@MainActor
enum ActiveCompanyAccess {
    static func role(
        companyID: UUID?,
        accountID: UUID?,
        memberships: [CompanyMembershipRecord]
    ) -> CompanyRole? {
        guard let companyID, let accountID else { return nil }
        return memberships.first {
            $0.companyID == companyID
                && $0.accountID == accountID
                && $0.isActive
        }?.role
    }
}

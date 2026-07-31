import Foundation
import SwiftData

@Model
final class CompanyRegistrationRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var registrationType: String
    var status: String
    var sourceName: String
    var sourceURL: String?
    var sourceUpdatedAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        registrationType: String,
        status: String,
        sourceName: String,
        sourceURL: String? = nil,
        sourceUpdatedAt: Date
    ) {
        self.id = id
        self.companyID = companyID
        self.registrationType = registrationType
        self.status = status
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.sourceUpdatedAt = sourceUpdatedAt
    }
}

@Model
final class DocumentVersionRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var documentID: UUID
    var versionNumber: Int
    var fileBookmark: Data
    var createdAt: Date
    var sourceName: String

    init(
        id: UUID = UUID(),
        companyID: UUID,
        documentID: UUID,
        versionNumber: Int,
        fileBookmark: Data,
        createdAt: Date = .now,
        sourceName: String
    ) {
        self.id = id
        self.companyID = companyID
        self.documentID = documentID
        self.versionNumber = versionNumber
        self.fileBookmark = fileBookmark
        self.createdAt = createdAt
        self.sourceName = sourceName
    }
}

@Model
final class IntegrationRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var providerIdentifier: String
    var displayName: String
    var stateRawValue: String
    var lastAttemptedAt: Date?
    var lastSuccessfulAt: Date?
    var lastErrorMessage: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        providerIdentifier: String,
        displayName: String,
        state: IntegrationState = .disconnected,
        lastAttemptedAt: Date? = nil,
        lastSuccessfulAt: Date? = nil,
        lastErrorMessage: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.providerIdentifier = providerIdentifier
        self.displayName = displayName
        stateRawValue = state.rawValue
        self.lastAttemptedAt = lastAttemptedAt
        self.lastSuccessfulAt = lastSuccessfulAt
        self.lastErrorMessage = lastErrorMessage
        self.createdAt = createdAt
    }

    var state: IntegrationState {
        get { IntegrationState(rawValue: stateRawValue) ?? .unavailable }
        set { stateRawValue = newValue.rawValue }
    }
}

enum IntegrationState: String, Codable, CaseIterable, Identifiable, Sendable {
    case disconnected
    case unauthorized
    case connected
    case refreshing
    case stale
    case rateLimited
    case unavailable
    case failed

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .disconnected: "Inte ansluten"
        case .unauthorized: "Behörighet saknas"
        case .connected: "Ansluten"
        case .refreshing: "Uppdaterar"
        case .stale: "Inaktuell"
        case .rateLimited: "Tillfälligt begränsad"
        case .unavailable: "Inte tillgänglig"
        case .failed: "Misslyckad"
        }
    }
}

@Model
final class NotificationPreferenceRecord {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var companyID: UUID?
    var categoryRawValue: String
    var isEnabled: Bool
    var leadTimeDays: Int
    var showsSensitiveDetails: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        accountID: UUID,
        companyID: UUID? = nil,
        category: NotificationCategory,
        isEnabled: Bool = true,
        leadTimeDays: Int = 7,
        showsSensitiveDetails: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.accountID = accountID
        self.companyID = companyID
        categoryRawValue = category.rawValue
        self.isEnabled = isEnabled
        self.leadTimeDays = leadTimeDays
        self.showsSensitiveDetails = showsSensitiveDetails
        self.updatedAt = updatedAt
    }

    var category: NotificationCategory {
        get { NotificationCategory(rawValue: categoryRawValue) ?? .deadlines }
        set {
            categoryRawValue = newValue.rawValue
            updatedAt = .now
        }
    }
}

enum NotificationCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case deadlines
    case approvals
    case assignedActions
    case integrations
    case officialDocuments
    case companyStatus
    case expiringContracts
    case missingInformation

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .deadlines: "Deadlines"
        case .approvals: "Godkännanden"
        case .assignedActions: "Tilldelade åtgärder"
        case .integrations: "Integrationer"
        case .officialDocuments: "Officiella dokument"
        case .companyStatus: "Bolagsstatus"
        case .expiringContracts: "Avtal som löper ut"
        case .missingInformation: "Uppgifter som saknas"
        }
    }
}

@Model
final class CompanyInvitationRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var email: String
    var displayName: String
    var roleRawValue: String
    var responsibilities: String
    var statusRawValue: String
    var invitedByAccountID: UUID
    var createdAt: Date
    var updatedAt: Date
    var expiresAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        email: String,
        displayName: String,
        role: CompanyRole,
        responsibilities: String,
        status: InvitationStatus = .awaitingDelivery,
        invitedByAccountID: UUID,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        expiresAt: Date = .now.addingTimeInterval(7 * 86_400)
    ) {
        self.id = id
        self.companyID = companyID
        self.email = email
        self.displayName = displayName
        roleRawValue = role.rawValue
        self.responsibilities = responsibilities
        statusRawValue = status.rawValue
        self.invitedByAccountID = invitedByAccountID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }

    var role: CompanyRole {
        get { CompanyRole(rawValue: roleRawValue) ?? .readOnlyAdvisor }
        set {
            roleRawValue = newValue.rawValue
            updatedAt = .now
        }
    }

    var status: InvitationStatus {
        get { InvitationStatus(rawValue: statusRawValue) ?? .awaitingDelivery }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = .now
        }
    }
}

enum InvitationStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case awaitingDelivery
    case delivered
    case accepted
    case expired
    case cancelled

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .awaitingDelivery: "Väntar på leverans"
        case .delivered: "Levererad"
        case .accepted: "Accepterad"
        case .expired: "Utgången"
        case .cancelled: "Avbruten"
        }
    }
}

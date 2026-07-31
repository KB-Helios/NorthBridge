import Foundation
import SwiftData

@Model
final class UserAccountRecord {
    @Attribute(.unique) var id: UUID
    var email: String
    var displayName: String
    var createdAt: Date
    var lastAuthenticatedAt: Date

    init(
        id: UUID = UUID(),
        email: String,
        displayName: String,
        createdAt: Date = .now,
        lastAuthenticatedAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.lastAuthenticatedAt = lastAuthenticatedAt
    }
}

@Model
final class CompanyRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var organisationNumber: String
    var registeredName: String
    var statusRawValue: String
    var sourceName: String
    var sourceURL: String?
    var sourceUpdatedAt: Date
    var lastSynchronizedAt: Date?
    var isStale: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        organisationNumber: String,
        registeredName: String,
        status: CompanyStatus,
        sourceName: String,
        sourceURL: String? = nil,
        sourceUpdatedAt: Date,
        lastSynchronizedAt: Date? = nil,
        isStale: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.organisationNumber = organisationNumber
        self.registeredName = registeredName
        statusRawValue = status.rawValue
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.sourceUpdatedAt = sourceUpdatedAt
        self.lastSynchronizedAt = lastSynchronizedAt
        self.isStale = isStale
        self.createdAt = createdAt
    }

    var status: CompanyStatus {
        get { CompanyStatus(rawValue: statusRawValue) ?? .unknown }
        set { statusRawValue = newValue.rawValue }
    }
}

enum CompanyStatus: String, Codable, CaseIterable, Sendable {
    case active
    case inactive
    case liquidation
    case bankruptcy
    case unknown

    var localizedName: String {
        switch self {
        case .active: "Aktivt"
        case .inactive: "Inaktivt"
        case .liquidation: "Likvidation"
        case .bankruptcy: "Konkurs"
        case .unknown: "Ej verifierat"
        }
    }
}

@Model
final class CompanyMembershipRecord {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var companyID: UUID
    var roleRawValue: String
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        accountID: UUID,
        companyID: UUID,
        role: CompanyRole,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.accountID = accountID
        self.companyID = companyID
        roleRawValue = role.rawValue
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var role: CompanyRole {
        get { CompanyRole(rawValue: roleRawValue) ?? .readOnlyAdvisor }
        set { roleRawValue = newValue.rawValue }
    }
}

@Model
final class DeadlineRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var title: String
    var dueAt: Date
    var details: String
    var responsibleName: String?
    var statusRawValue: String
    var priorityRawValue: String
    var sourceName: String
    var sourceURL: String?
    var ruleIdentifier: String?
    var ruleVersion: String?
    var ruleEffectiveAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        title: String,
        dueAt: Date,
        details: String,
        responsibleName: String? = nil,
        status: DeadlineStatus = .open,
        priority: DeadlinePriority = .normal,
        sourceName: String,
        sourceURL: String? = nil,
        ruleIdentifier: String? = nil,
        ruleVersion: String? = nil,
        ruleEffectiveAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.title = title
        self.dueAt = dueAt
        self.details = details
        self.responsibleName = responsibleName
        statusRawValue = status.rawValue
        priorityRawValue = priority.rawValue
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.ruleIdentifier = ruleIdentifier
        self.ruleVersion = ruleVersion
        self.ruleEffectiveAt = ruleEffectiveAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var status: DeadlineStatus {
        get { DeadlineStatus(rawValue: statusRawValue) ?? .open }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = .now
        }
    }

    var priority: DeadlinePriority {
        get { DeadlinePriority(rawValue: priorityRawValue) ?? .normal }
        set {
            priorityRawValue = newValue.rawValue
            updatedAt = .now
        }
    }
}

enum DeadlineStatus: String, Codable, CaseIterable, Sendable {
    case open
    case inProgress
    case completed
    case dismissed

    var localizedName: String {
        switch self {
        case .open: "Öppen"
        case .inProgress: "Pågår"
        case .completed: "Klar"
        case .dismissed: "Avfärdad"
        }
    }
}

enum DeadlinePriority: String, Codable, CaseIterable, Sendable {
    case low
    case normal
    case high
    case critical

    var localizedName: String {
        switch self {
        case .low: "Låg"
        case .normal: "Normal"
        case .high: "Hög"
        case .critical: "Kritisk"
        }
    }
}

@Model
final class DocumentRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var title: String
    var categoryRawValue: String
    var fileBookmark: Data?
    var originalFilename: String?
    var uniformTypeIdentifier: String?
    var extractedText: String?
    var detectedOrganisationNumbers: String?
    var detectedParties: String?
    var tags: String
    var pageCount: Int?
    var importedAt: Date
    var lastModifiedAt: Date
    var sourceName: String
    var isFavorite: Bool
    var isAvailableOffline: Bool
    var expiresAt: Date?

    init(
        id: UUID = UUID(),
        companyID: UUID,
        title: String,
        category: DocumentCategory,
        fileBookmark: Data? = nil,
        originalFilename: String? = nil,
        uniformTypeIdentifier: String? = nil,
        extractedText: String? = nil,
        detectedOrganisationNumbers: String? = nil,
        detectedParties: String? = nil,
        tags: String = "",
        pageCount: Int? = nil,
        importedAt: Date = .now,
        lastModifiedAt: Date = .now,
        sourceName: String,
        isFavorite: Bool = false,
        isAvailableOffline: Bool = true,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.companyID = companyID
        self.title = title
        categoryRawValue = category.rawValue
        self.fileBookmark = fileBookmark
        self.originalFilename = originalFilename
        self.uniformTypeIdentifier = uniformTypeIdentifier
        self.extractedText = extractedText
        self.detectedOrganisationNumbers = detectedOrganisationNumbers
        self.detectedParties = detectedParties
        self.tags = tags
        self.pageCount = pageCount
        self.importedAt = importedAt
        self.lastModifiedAt = lastModifiedAt
        self.sourceName = sourceName
        self.isFavorite = isFavorite
        self.isAvailableOffline = isAvailableOffline
        self.expiresAt = expiresAt
    }

    var category: DocumentCategory {
        get { DocumentCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }
}

@Model
final class FinancialMetricRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var kindRawValue: String
    var amount: Double
    var currencyCode: String
    var periodStart: Date
    var periodEnd: Date
    var sourceName: String
    var sourceUpdatedAt: Date
    var valueStateRawValue: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        kind: FinancialMetricKind,
        amount: Double,
        currencyCode: String = "SEK",
        periodStart: Date,
        periodEnd: Date,
        sourceName: String,
        sourceUpdatedAt: Date = .now,
        valueState: FinancialValueState = .manuallyEntered,
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        kindRawValue = kind.rawValue
        self.amount = amount
        self.currencyCode = currencyCode
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.sourceName = sourceName
        self.sourceUpdatedAt = sourceUpdatedAt
        valueStateRawValue = valueState.rawValue
        self.createdAt = createdAt
    }

    var kind: FinancialMetricKind {
        get { FinancialMetricKind(rawValue: kindRawValue) ?? .revenue }
        set { kindRawValue = newValue.rawValue }
    }

    var valueState: FinancialValueState {
        get { FinancialValueState(rawValue: valueStateRawValue) ?? .manuallyEntered }
        set { valueStateRawValue = newValue.rawValue }
    }
}

enum FinancialMetricKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case bankBalance
    case availableLiquidity
    case revenue
    case expenses
    case operatingResult
    case accountsReceivable
    case accountsPayable
    case taxObligations
    case vatPayable
    case grossPayroll

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .bankBalance: "Banksaldo"
        case .availableLiquidity: "Tillgänglig likviditet"
        case .revenue: "Intäkter"
        case .expenses: "Kostnader"
        case .operatingResult: "Rörelseresultat"
        case .accountsReceivable: "Kundfordringar"
        case .accountsPayable: "Leverantörsskulder"
        case .taxObligations: "Skatteåtaganden"
        case .vatPayable: "Moms att redovisa"
        case .grossPayroll: "Bruttolön"
        }
    }
}

enum FinancialValueState: String, Codable, CaseIterable, Identifiable, Sendable {
    case booked
    case estimated
    case forecast
    case manuallyEntered

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .booked: "Bokfört"
        case .estimated: "Uppskattat"
        case .forecast: "Prognos"
        case .manuallyEntered: "Manuellt angivet"
        }
    }
}

enum DocumentCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case registrationCertificate
    case articlesOfAssociation
    case annualReports
    case boardMinutes
    case generalMeetingMinutes
    case shareholderAgreement
    case shareholderRegister
    case shareCertificate
    case taxDocuments
    case agreements
    case insurance
    case powersOfAttorney
    case other

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .registrationCertificate: "Registreringsbevis"
        case .articlesOfAssociation: "Bolagsordning"
        case .annualReports: "Årsredovisningar"
        case .boardMinutes: "Styrelseprotokoll"
        case .generalMeetingMinutes: "Stämmoprotokoll"
        case .shareholderAgreement: "Aktieägaravtal"
        case .shareholderRegister: "Aktiebok"
        case .shareCertificate: "Aktiebrev"
        case .taxDocuments: "Skattehandlingar"
        case .agreements: "Avtal"
        case .insurance: "Försäkringar"
        case .powersOfAttorney: "Fullmakter"
        case .other: "Övrigt"
        }
    }
}

@Model
final class AuditEventRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID?
    var accountID: UUID?
    var action: String
    var entityType: String
    var entityID: UUID?
    var occurredAt: Date
    var summary: String

    init(
        id: UUID = UUID(),
        companyID: UUID? = nil,
        accountID: UUID? = nil,
        action: String,
        entityType: String,
        entityID: UUID? = nil,
        occurredAt: Date = .now,
        summary: String
    ) {
        self.id = id
        self.companyID = companyID
        self.accountID = accountID
        self.action = action
        self.entityType = entityType
        self.entityID = entityID
        self.occurredAt = occurredAt
        self.summary = summary
    }
}

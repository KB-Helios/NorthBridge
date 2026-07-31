import Foundation
import SwiftData

@Model
final class CompanyProfileRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var companyType: String
    var registeredOffice: String
    var incorporationDate: Date?
    var fiscalYearStartMonth: Int
    var fiscalYearStartDay: Int
    var fiscalYearEndMonth: Int
    var fiscalYearEndDay: Int
    var businessDescription: String
    var shareCapital: Double?
    var shareCapitalCurrencyCode: String
    var sourceName: String
    var sourceURL: String?
    var sourceUpdatedAt: Date
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        companyType: String = "Aktiebolag",
        registeredOffice: String = "",
        incorporationDate: Date? = nil,
        fiscalYearStartMonth: Int = 1,
        fiscalYearStartDay: Int = 1,
        fiscalYearEndMonth: Int = 12,
        fiscalYearEndDay: Int = 31,
        businessDescription: String = "",
        shareCapital: Double? = nil,
        shareCapitalCurrencyCode: String = "SEK",
        sourceName: String,
        sourceURL: String? = nil,
        sourceUpdatedAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.companyType = companyType
        self.registeredOffice = registeredOffice
        self.incorporationDate = incorporationDate
        self.fiscalYearStartMonth = fiscalYearStartMonth
        self.fiscalYearStartDay = fiscalYearStartDay
        self.fiscalYearEndMonth = fiscalYearEndMonth
        self.fiscalYearEndDay = fiscalYearEndDay
        self.businessDescription = businessDescription
        self.shareCapital = shareCapital
        self.shareCapitalCurrencyCode = shareCapitalCurrencyCode
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.sourceUpdatedAt = sourceUpdatedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class BeneficialOwnerRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var displayName: String
    var identityReference: String?
    var controlDescription: String
    var ownershipPercentLowerBound: Double?
    var ownershipPercentUpperBound: Double?
    var sourceName: String
    var sourceURL: String?
    var sourceUpdatedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        displayName: String,
        identityReference: String? = nil,
        controlDescription: String,
        ownershipPercentLowerBound: Double? = nil,
        ownershipPercentUpperBound: Double? = nil,
        sourceName: String,
        sourceURL: String? = nil,
        sourceUpdatedAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.displayName = displayName
        self.identityReference = identityReference
        self.controlDescription = controlDescription
        self.ownershipPercentLowerBound = ownershipPercentLowerBound
        self.ownershipPercentUpperBound = ownershipPercentUpperBound
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.sourceUpdatedAt = sourceUpdatedAt
        self.createdAt = createdAt
    }
}

@Model
final class CompanyIndustryCodeRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var code: String
    var codeDescription: String
    var isPrimary: Bool
    var sourceName: String
    var sourceURL: String?
    var sourceUpdatedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        code: String,
        codeDescription: String,
        isPrimary: Bool = false,
        sourceName: String,
        sourceURL: String? = nil,
        sourceUpdatedAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.code = code
        self.codeDescription = codeDescription
        self.isPrimary = isPrimary
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.sourceUpdatedAt = sourceUpdatedAt
        self.createdAt = createdAt
    }
}

@Model
final class CompanyHistoryEventRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var title: String
    var details: String
    var effectiveAt: Date
    var sourceName: String
    var sourceURL: String?
    var sourceUpdatedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        title: String,
        details: String,
        effectiveAt: Date,
        sourceName: String,
        sourceURL: String? = nil,
        sourceUpdatedAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.title = title
        self.details = details
        self.effectiveAt = effectiveAt
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.sourceUpdatedAt = sourceUpdatedAt
        self.createdAt = createdAt
    }
}

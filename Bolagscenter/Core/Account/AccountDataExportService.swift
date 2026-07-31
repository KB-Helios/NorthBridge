import Foundation
import SwiftData

struct PortableAccountExport: Codable, Sendable {
    let format: String
    let formatVersion: Int
    let exportedAt: Date
    let accountID: UUID
    let notice: String
    let records: [PortableExportRecord]
}

struct PortableExportRecord: Codable, Sendable {
    let type: String
    let id: UUID
    let attributes: [String: String]
}

enum AccountDataExportError: LocalizedError {
    case accountNotFound

    var errorDescription: String? {
        switch self {
        case .accountNotFound:
            "Kontot kunde inte hittas och exporten skapades inte."
        }
    }
}

@MainActor
struct AccountDataExportService {
    func export(accountID: UUID, from context: ModelContext) throws -> URL {
        let accounts = try context.fetch(FetchDescriptor<UserAccountRecord>())
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            throw AccountDataExportError.accountNotFound
        }

        let allMemberships = try context.fetch(FetchDescriptor<CompanyMembershipRecord>())
        let accountMemberships = allMemberships.filter { $0.accountID == accountID }
        let companyIDs = Set(accountMemberships.map(\.companyID))

        var records = [
            record(
                "userAccount",
                account.id,
                ("email", account.email),
                ("displayName", account.displayName),
                ("createdAt", string(account.createdAt)),
                ("lastAuthenticatedAt", string(account.lastAuthenticatedAt))
            )
        ]

        records += accountMemberships.map {
            record(
                "companyMembership",
                $0.id,
                ("accountID", string($0.accountID)),
                ("companyID", string($0.companyID)),
                ("role", $0.role.rawValue),
                ("isActive", string($0.isActive)),
                ("createdAt", string($0.createdAt))
            )
        }

        records += try context.fetch(FetchDescriptor<CompanyResponsibilityRecord>())
            .filter { $0.accountID == accountID && companyIDs.contains($0.companyID) }
            .map {
                record(
                    "companyResponsibility",
                    $0.id,
                    ("accountID", string($0.accountID)),
                    ("companyID", string($0.companyID)),
                    ("category", $0.category.rawValue),
                    ("isPrimary", string($0.isPrimary)),
                    ("createdAt", string($0.createdAt)),
                    ("updatedAt", string($0.updatedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<CompanyRecord>())
            .filter { companyIDs.contains($0.id) }
            .map {
                record(
                    "company",
                    $0.id,
                    ("organisationNumber", $0.organisationNumber),
                    ("registeredName", $0.registeredName),
                    ("status", $0.status.rawValue),
                    ("sourceName", $0.sourceName),
                    ("sourceURL", $0.sourceURL),
                    ("sourceUpdatedAt", string($0.sourceUpdatedAt)),
                    ("lastSynchronizedAt", string($0.lastSynchronizedAt)),
                    ("isStale", string($0.isStale)),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<CompanyProfileRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "companyProfile",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("companyType", $0.companyType),
                    ("registeredOffice", $0.registeredOffice),
                    ("incorporationDate", string($0.incorporationDate)),
                    ("fiscalYearStartMonth", string($0.fiscalYearStartMonth)),
                    ("fiscalYearStartDay", string($0.fiscalYearStartDay)),
                    ("fiscalYearEndMonth", string($0.fiscalYearEndMonth)),
                    ("fiscalYearEndDay", string($0.fiscalYearEndDay)),
                    ("businessDescription", $0.businessDescription),
                    ("shareCapital", string($0.shareCapital)),
                    ("shareCapitalCurrencyCode", $0.shareCapitalCurrencyCode),
                    ("sourceName", $0.sourceName),
                    ("sourceURL", $0.sourceURL),
                    ("sourceUpdatedAt", string($0.sourceUpdatedAt)),
                    ("createdAt", string($0.createdAt)),
                    ("updatedAt", string($0.updatedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<CompanyRegistrationRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "companyRegistration",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("registrationType", $0.registrationType),
                    ("status", $0.status),
                    ("sourceName", $0.sourceName),
                    ("sourceURL", $0.sourceURL),
                    ("sourceUpdatedAt", string($0.sourceUpdatedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<BeneficialOwnerRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "beneficialOwner",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("displayName", $0.displayName),
                    ("identityReference", $0.identityReference),
                    ("controlDescription", $0.controlDescription),
                    ("ownershipPercentLowerBound", string($0.ownershipPercentLowerBound)),
                    ("ownershipPercentUpperBound", string($0.ownershipPercentUpperBound)),
                    ("sourceName", $0.sourceName),
                    ("sourceURL", $0.sourceURL),
                    ("sourceUpdatedAt", string($0.sourceUpdatedAt)),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<CompanyIndustryCodeRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "companyIndustryCode",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("code", $0.code),
                    ("codeDescription", $0.codeDescription),
                    ("isPrimary", string($0.isPrimary)),
                    ("sourceName", $0.sourceName),
                    ("sourceURL", $0.sourceURL),
                    ("sourceUpdatedAt", string($0.sourceUpdatedAt)),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<CompanyHistoryEventRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "companyHistoryEvent",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("title", $0.title),
                    ("details", $0.details),
                    ("effectiveAt", string($0.effectiveAt)),
                    ("sourceName", $0.sourceName),
                    ("sourceURL", $0.sourceURL),
                    ("sourceUpdatedAt", string($0.sourceUpdatedAt)),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<PersonRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "person",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("fullName", $0.fullName),
                    ("email", $0.email),
                    ("phone", $0.phone),
                    ("personalIdentifier", $0.personalIdentifier),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<BoardMemberRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "boardMember",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("personID", string($0.personID)),
                    ("role", $0.role.rawValue),
                    ("isSignatory", string($0.isSignatory)),
                    ("mandateStartsAt", string($0.mandateStartsAt)),
                    ("mandateEndsAt", string($0.mandateEndsAt)),
                    ("sourceName", $0.sourceName),
                    ("sourceUpdatedAt", string($0.sourceUpdatedAt)),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<BoardMeetingRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "boardMeeting",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("title", $0.title),
                    ("meetingNumber", $0.meetingNumber),
                    ("scheduledAt", string($0.scheduledAt)),
                    ("location", $0.location),
                    ("status", $0.status.rawValue),
                    ("notes", $0.notes),
                    ("createdAt", string($0.createdAt)),
                    ("updatedAt", string($0.updatedAt)),
                    ("approvedAt", string($0.approvedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<MeetingAttendanceRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "meetingAttendance",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("meetingID", string($0.meetingID)),
                    ("personID", string($0.personID)),
                    ("attendance", $0.attendance.rawValue),
                    ("recordedAt", string($0.recordedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<AgendaItemRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "agendaItem",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("meetingID", string($0.meetingID)),
                    ("position", string($0.position)),
                    ("title", $0.title),
                    ("details", $0.details),
                    ("presenterName", $0.presenterName),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<BoardResolutionRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "boardResolution",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("meetingID", string($0.meetingID)),
                    ("agendaItemID", string($0.agendaItemID)),
                    ("title", $0.title),
                    ("decisionText", $0.decisionText),
                    ("status", $0.status.rawValue),
                    ("decidedAt", string($0.decidedAt)),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<ActionItemRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "actionItem",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("meetingID", string($0.meetingID)),
                    ("resolutionID", string($0.resolutionID)),
                    ("title", $0.title),
                    ("details", $0.details),
                    ("assignedTo", $0.assignedTo),
                    ("dueAt", string($0.dueAt)),
                    ("status", $0.status.rawValue),
                    ("priority", $0.priority.rawValue),
                    ("createdAt", string($0.createdAt)),
                    ("updatedAt", string($0.updatedAt)),
                    ("completedAt", string($0.completedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<ShareholderRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "shareholder",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("displayName", $0.displayName),
                    ("shareholderKind", $0.shareholderKind.rawValue),
                    ("identityReference", $0.identityReference),
                    ("email", $0.email),
                    ("postalAddress", $0.postalAddress),
                    ("createdAt", string($0.createdAt)),
                    ("archivedAt", string($0.archivedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<ShareClassRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "shareClass",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("name", $0.name),
                    ("votesPerShare", string($0.votesPerShare)),
                    ("nominalValue", string($0.nominalValue)),
                    ("currencyCode", $0.currencyCode),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<ShareTransactionRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "shareTransaction",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("shareClassID", string($0.shareClassID)),
                    ("fromShareholderID", string($0.fromShareholderID)),
                    ("toShareholderID", string($0.toShareholderID)),
                    ("quantity", string($0.quantity)),
                    ("kind", $0.kind.rawValue),
                    ("transactionDate", string($0.transactionDate)),
                    ("reference", $0.reference),
                    ("notes", $0.notes),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<ShareCertificateRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "shareCertificate",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("shareholderID", string($0.shareholderID)),
                    ("shareClassID", string($0.shareClassID)),
                    ("certificateNumber", $0.certificateNumber),
                    ("quantity", string($0.quantity)),
                    ("shareNumberFrom", string($0.shareNumberFrom)),
                    ("shareNumberTo", string($0.shareNumberTo)),
                    ("issuedAt", string($0.issuedAt)),
                    ("status", $0.status.rawValue),
                    ("revokedAt", string($0.revokedAt)),
                    ("notes", $0.notes),
                    ("createdAt", string($0.createdAt)),
                    ("updatedAt", string($0.updatedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<DocumentRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "document",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("title", $0.title),
                    ("category", $0.category.rawValue),
                    ("originalFilename", $0.originalFilename),
                    ("uniformTypeIdentifier", $0.uniformTypeIdentifier),
                    ("extractedText", $0.extractedText),
                    ("detectedOrganisationNumbers", $0.detectedOrganisationNumbers),
                    ("detectedParties", $0.detectedParties),
                    ("tags", $0.tags),
                    ("pageCount", string($0.pageCount)),
                    ("importedAt", string($0.importedAt)),
                    ("lastModifiedAt", string($0.lastModifiedAt)),
                    ("sourceName", $0.sourceName),
                    ("isFavorite", string($0.isFavorite)),
                    ("isAvailableOffline", string($0.isAvailableOffline)),
                    ("expiresAt", string($0.expiresAt)),
                    ("portableFileIncluded", "false")
                )
            }

        records += try context.fetch(FetchDescriptor<DocumentVersionRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "documentVersion",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("documentID", string($0.documentID)),
                    ("versionNumber", string($0.versionNumber)),
                    ("createdAt", string($0.createdAt)),
                    ("sourceName", $0.sourceName),
                    ("portableFileIncluded", "false")
                )
            }

        records += try context.fetch(FetchDescriptor<DeadlineRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "deadline",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("title", $0.title),
                    ("dueAt", string($0.dueAt)),
                    ("details", $0.details),
                    ("responsibleName", $0.responsibleName),
                    ("status", $0.status.rawValue),
                    ("priority", $0.priority.rawValue),
                    ("sourceName", $0.sourceName),
                    ("sourceURL", $0.sourceURL),
                    ("ruleIdentifier", $0.ruleIdentifier),
                    ("ruleVersion", $0.ruleVersion),
                    ("ruleEffectiveAt", string($0.ruleEffectiveAt)),
                    ("createdAt", string($0.createdAt)),
                    ("updatedAt", string($0.updatedAt))
                )
            }

        records += try context.fetch(
            FetchDescriptor<DeadlineSupportingDocumentRecord>()
        )
        .filter { companyIDs.contains($0.companyID) }
        .map {
            record(
                "deadlineSupportingDocument",
                $0.id,
                ("companyID", string($0.companyID)),
                ("deadlineID", string($0.deadlineID)),
                ("documentID", string($0.documentID)),
                ("attachedByAccountID", string($0.attachedByAccountID)),
                ("attachedAt", string($0.attachedAt))
            )
        }

        records += try context.fetch(FetchDescriptor<DeadlineReminderRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "deadlineReminder",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("deadlineID", string($0.deadlineID)),
                    ("isEnabled", string($0.isEnabled)),
                    ("leadTimeDays", string($0.leadTimeDays)),
                    ("createdAt", string($0.createdAt)),
                    ("updatedAt", string($0.updatedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<DeadlineActionEventRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "deadlineActionEvent",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("deadlineID", string($0.deadlineID)),
                    ("accountID", string($0.accountID)),
                    ("kind", $0.kind.rawValue),
                    ("details", $0.details),
                    ("occurredAt", string($0.occurredAt))
                )
            }

        records += try context.fetch(FetchDescriptor<FinancialMetricRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "financialMetric",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("kind", $0.kind.rawValue),
                    ("amount", string($0.amount)),
                    ("currencyCode", $0.currencyCode),
                    ("periodStart", string($0.periodStart)),
                    ("periodEnd", string($0.periodEnd)),
                    ("sourceName", $0.sourceName),
                    ("sourceUpdatedAt", string($0.sourceUpdatedAt)),
                    ("valueState", $0.valueState.rawValue),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<FinancialPlanRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "financialPlan",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("title", $0.title),
                    ("currencyCode", $0.currencyCode),
                    ("availableCash", string($0.availableCash)),
                    ("monthlyRevenue", string($0.monthlyRevenue)),
                    ("monthlyCosts", string($0.monthlyCosts)),
                    ("proposedGrossSalary", string($0.proposedGrossSalary)),
                    ("proposedDividend", string($0.proposedDividend)),
                    ("salaryTaxRate", string($0.salaryTaxRate)),
                    ("dividendTaxRate", string($0.dividendTaxRate)),
                    ("expectedTaxPayments", string($0.expectedTaxPayments)),
                    ("horizonMonths", string($0.horizonMonths)),
                    ("assumptions", $0.assumptions),
                    ("createdAt", string($0.createdAt)),
                    ("updatedAt", string($0.updatedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<IntegrationRecord>())
            .filter { companyIDs.contains($0.companyID) }
            .map {
                record(
                    "integration",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("providerIdentifier", $0.providerIdentifier),
                    ("displayName", $0.displayName),
                    ("state", $0.state.rawValue),
                    ("lastAttemptedAt", string($0.lastAttemptedAt)),
                    ("lastSuccessfulAt", string($0.lastSuccessfulAt)),
                    ("lastErrorMessage", $0.lastErrorMessage),
                    ("createdAt", string($0.createdAt))
                )
            }

        records += try context.fetch(FetchDescriptor<NotificationPreferenceRecord>())
            .filter { $0.accountID == accountID }
            .map {
                record(
                    "notificationPreference",
                    $0.id,
                    ("accountID", string($0.accountID)),
                    ("companyID", string($0.companyID)),
                    ("category", $0.category.rawValue),
                    ("isEnabled", string($0.isEnabled)),
                    ("leadTimeDays", string($0.leadTimeDays)),
                    ("showsSensitiveDetails", string($0.showsSensitiveDetails)),
                    ("updatedAt", string($0.updatedAt))
                )
            }

        records += try context.fetch(FetchDescriptor<CompanyInvitationRecord>())
            .filter {
                $0.invitedByAccountID == accountID || companyIDs.contains($0.companyID)
            }
            .map {
                record(
                    "companyInvitation",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("email", $0.email),
                    ("displayName", $0.displayName),
                    ("role", $0.role.rawValue),
                    ("responsibilities", $0.responsibilities),
                    ("status", $0.status.rawValue),
                    ("invitedByAccountID", string($0.invitedByAccountID)),
                    ("createdAt", string($0.createdAt)),
                    ("updatedAt", string($0.updatedAt)),
                    ("expiresAt", string($0.expiresAt))
                )
            }

        records += try context.fetch(FetchDescriptor<AuditEventRecord>())
            .filter {
                $0.accountID == accountID
                    || $0.companyID.map(companyIDs.contains) == true
            }
            .map {
                record(
                    "auditEvent",
                    $0.id,
                    ("companyID", string($0.companyID)),
                    ("accountID", string($0.accountID)),
                    ("action", $0.action),
                    ("entityType", $0.entityType),
                    ("entityID", string($0.entityID)),
                    ("occurredAt", string($0.occurredAt)),
                    ("summary", $0.summary)
                )
            }

        records.sort {
            if $0.type == $1.type {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.type < $1.type
        }

        let export = PortableAccountExport(
            format: "com.kbhelios.northbridge.portable-account-data",
            formatVersion: 1,
            exportedAt: .now,
            accountID: accountID,
            notice: "Dokumentmetadata ingår. Själva dokumentfilerna exporteras från dokumentvyn för att inte skapa oskyddade dubbletter.",
            records: records
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(export)
        return try write(data, accountID: accountID)
    }

    private func write(_ data: Data, accountID: UUID) throws -> URL {
        let fileManager = FileManager.default
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appending(path: "SecureExports", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )

        let fileURL = root.appending(
            path: "NorthBridge-data-\(accountID.uuidString.prefix(8)).json",
            directoryHint: .notDirectory
        )
        try? fileManager.removeItem(at: fileURL)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        return fileURL
    }

    private func record(
        _ type: String,
        _ id: UUID,
        _ values: (String, String?)...
    ) -> PortableExportRecord {
        PortableExportRecord(
            type: type,
            id: id,
            attributes: Dictionary(
                uniqueKeysWithValues: values.compactMap { key, value in
                    value.map { (key, $0) }
                }
            )
        )
    }

    private func string(_ value: UUID?) -> String? {
        value?.uuidString
    }

    private func string(_ value: Date?) -> String? {
        value?.ISO8601Format()
    }

    private func string(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    private func string(_ value: Int?) -> String? {
        value.map { String($0) }
    }

    private func string(_ value: Double?) -> String? {
        value.map { String($0) }
    }
}

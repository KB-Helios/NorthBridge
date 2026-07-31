import Foundation
import SwiftData

struct AccountDeletionReport: Equatable, Sendable {
    let deletedCompanies: Int
    let retainedSharedCompanies: Int
}

enum AccountDeletionError: LocalizedError {
    case accountNotFound

    var errorDescription: String? {
        switch self {
        case .accountNotFound:
            "Kontot kunde inte hittas och inga data raderades."
        }
    }
}

@MainActor
struct AccountDeletionService {
    private let fileManager: FileManager
    private let applicationSupportDirectory: URL?

    init(
        fileManager: FileManager = .default,
        applicationSupportDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.applicationSupportDirectory = applicationSupportDirectory
    }

    func delete(accountID: UUID, from context: ModelContext) throws -> AccountDeletionReport {
        let accounts = try context.fetch(FetchDescriptor<UserAccountRecord>())
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            throw AccountDeletionError.accountNotFound
        }

        let memberships = try context.fetch(FetchDescriptor<CompanyMembershipRecord>())
        let accountCompanyIDs = Set(
            memberships
                .filter { $0.accountID == accountID }
                .map(\.companyID)
        )
        let retainedCompanyIDs = Set(
            memberships
                .filter {
                    $0.accountID != accountID
                        && $0.isActive
                        && accountCompanyIDs.contains($0.companyID)
                }
                .map(\.companyID)
        )
        let deletedCompanyIDs = accountCompanyIDs.subtracting(retainedCompanyIDs)

        try deleteProtectedDocumentFiles(
            companyIDs: deletedCompanyIDs,
            context: context
        )
        deleteGeneratedArtifacts(
            accountID: accountID,
            companyIDs: deletedCompanyIDs
        )
        try deleteCompanyData(companyIDs: deletedCompanyIDs, context: context)

        for membership in memberships where membership.accountID == accountID {
            context.delete(membership)
        }
        for responsibility in try context.fetch(
            FetchDescriptor<CompanyResponsibilityRecord>()
        ) where responsibility.accountID == accountID {
            context.delete(responsibility)
        }
        for preference in try context.fetch(FetchDescriptor<NotificationPreferenceRecord>())
        where preference.accountID == accountID {
            context.delete(preference)
        }
        for invitation in try context.fetch(FetchDescriptor<CompanyInvitationRecord>())
        where invitation.invitedByAccountID == accountID {
            context.delete(invitation)
        }
        for event in try context.fetch(FetchDescriptor<AuditEventRecord>())
        where event.accountID == accountID {
            event.accountID = nil
            event.summary = "Händelsen utfördes av ett raderat konto."
        }

        context.delete(account)
        try context.save()

        return AccountDeletionReport(
            deletedCompanies: deletedCompanyIDs.count,
            retainedSharedCompanies: retainedCompanyIDs.count
        )
    }

    private func deleteCompanyData(
        companyIDs: Set<UUID>,
        context: ModelContext
    ) throws {
        guard !companyIDs.isEmpty else { return }

        for value in try context.fetch(FetchDescriptor<CompanyProfileRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<CompanyResponsibilityRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<CompanyRegistrationRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<BeneficialOwnerRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<CompanyIndustryCodeRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<CompanyHistoryEventRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<PersonRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<BoardMemberRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<BoardMeetingRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<MeetingAttendanceRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<AgendaItemRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<BoardResolutionRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<ActionItemRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<ShareholderRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<ShareClassRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<ShareTransactionRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<ShareCertificateRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<DocumentRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<DocumentVersionRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<DeadlineRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(
            FetchDescriptor<DeadlineSupportingDocumentRecord>()
        ) where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<DeadlineReminderRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<DeadlineActionEventRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<FinancialMetricRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<FinancialPlanRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<IntegrationRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<NotificationPreferenceRecord>())
        where value.companyID.map(companyIDs.contains) == true {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<CompanyInvitationRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<AuditEventRecord>())
        where value.companyID.map(companyIDs.contains) == true {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<CompanyMembershipRecord>())
        where companyIDs.contains(value.companyID) {
            context.delete(value)
        }
        for value in try context.fetch(FetchDescriptor<CompanyRecord>())
        where companyIDs.contains(value.id) {
            context.delete(value)
        }
    }

    private func deleteProtectedDocumentFiles(
        companyIDs: Set<UUID>,
        context: ModelContext
    ) throws {
        guard !companyIDs.isEmpty else { return }
        let documents = try context.fetch(FetchDescriptor<DocumentRecord>())
            .filter { companyIDs.contains($0.companyID) }
        let versions = try context.fetch(FetchDescriptor<DocumentVersionRecord>())
            .filter { companyIDs.contains($0.companyID) }
        for bookmark in documents.compactMap(\.fileBookmark)
            + versions.map(\.fileBookmark) {
            removeAppOwnedFile(bookmark: bookmark)
        }
    }

    private func removeAppOwnedFile(bookmark: Data) {
        do {
            var stale = false
            let fileURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ).standardizedFileURL
            let documentsRoot = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ).standardizedFileURL
            let applicationSupportRoot = try resolvedApplicationSupportDirectory()
            let allowedRoots = [
                documentsRoot,
                applicationSupportRoot
                    .appending(path: "Documents", directoryHint: .isDirectory)
                    .standardizedFileURL,
                applicationSupportRoot
                    .appending(path: "GeneratedDocuments", directoryHint: .isDirectory)
                    .standardizedFileURL
            ]
            guard allowedRoots.contains(where: {
                isStrictDescendant(fileURL, of: $0)
            }) else {
                SecureLogger.security.fault(
                    "Account deletion refused a bookmarked file outside app-owned roots."
                )
                return
            }
            try? fileManager.removeItem(at: fileURL)
        } catch {
            SecureLogger.security.error(
                "Account deletion could not resolve a protected file: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }

    private func deleteGeneratedArtifacts(
        accountID: UUID,
        companyIDs: Set<UUID>
    ) {
        do {
            let root = try resolvedApplicationSupportDirectory()
            let generatedDocumentsRoot = root
                .appending(path: "GeneratedDocuments", directoryHint: .isDirectory)
                .standardizedFileURL

            for companyID in companyIDs {
                let companyDirectory = generatedDocumentsRoot
                    .appending(path: companyID.uuidString, directoryHint: .isDirectory)
                    .standardizedFileURL
                removeArtifactIfPresent(
                    at: companyDirectory,
                    within: generatedDocumentsRoot
                )
            }

            let exportsRoot = root
                .appending(path: "SecureExports", directoryHint: .isDirectory)
                .standardizedFileURL
            let exportURL = exportsRoot
                .appending(
                    path: "NorthBridge-data-\(accountID.uuidString.prefix(8)).json",
                    directoryHint: .notDirectory
                )
                .standardizedFileURL
            removeArtifactIfPresent(at: exportURL, within: exportsRoot)
        } catch {
            SecureLogger.security.error(
                "Account deletion could not clean generated artifacts: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }

    private func resolvedApplicationSupportDirectory() throws -> URL {
        if let applicationSupportDirectory {
            return applicationSupportDirectory.standardizedFileURL
        }
        return try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).standardizedFileURL
    }

    private func removeArtifactIfPresent(
        at artifactURL: URL,
        within rootURL: URL
    ) {
        guard isStrictDescendant(artifactURL, of: rootURL) else {
            SecureLogger.security.fault(
                "Account deletion refused an artifact path outside its expected root."
            )
            return
        }
        guard fileManager.fileExists(atPath: artifactURL.path) else { return }

        do {
            try fileManager.removeItem(at: artifactURL)
        } catch {
            SecureLogger.security.error(
                "Account deletion could not remove an app-owned artifact: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }

    private func isStrictDescendant(_ candidateURL: URL, of rootURL: URL) -> Bool {
        let rootComponents = rootURL
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .pathComponents
        let candidateComponents = candidateURL
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .pathComponents

        guard candidateComponents.count > rootComponents.count else {
            return false
        }
        return candidateComponents
            .prefix(rootComponents.count)
            .elementsEqual(rootComponents)
    }
}

import Foundation
import SwiftData
import Testing
@testable import Bolagscenter

@MainActor
struct AccountDeletionServiceTests {
    @Test
    func deletingSoleAccountPurgesUnsharedCompanyData() throws {
        let context = try makeContext()
        let account = UserAccountRecord(
            email: "owner@example.se",
            displayName: "Owner"
        )
        let company = CompanyRecord(
            organisationNumber: "556016-0680",
            registeredName: "Example AB",
            status: .active,
            sourceName: "Test",
            sourceUpdatedAt: .now
        )
        context.insert(account)
        context.insert(company)
        context.insert(
            CompanyMembershipRecord(
                accountID: account.id,
                companyID: company.id,
                role: .owner
            )
        )
        context.insert(
            DeadlineRecord(
                companyID: company.id,
                title: "Deadline",
                dueAt: .now.addingTimeInterval(86_400),
                details: "Test",
                sourceName: "Test"
            )
        )
        let shareholder = ShareholderRecord(
            companyID: company.id,
            displayName: "Owner",
            shareholderKind: .person
        )
        let shareClass = ShareClassRecord(
            companyID: company.id,
            name: "A"
        )
        context.insert(shareholder)
        context.insert(shareClass)
        context.insert(
            ShareCertificateRecord(
                companyID: company.id,
                shareholderID: shareholder.id,
                shareClassID: shareClass.id,
                certificateNumber: "AB-1",
                quantity: 100,
                issuedAt: .now,
                status: .draft
            )
        )
        try context.save()

        let report = try AccountDeletionService().delete(
            accountID: account.id,
            from: context
        )

        #expect(report.deletedCompanies == 1)
        #expect(report.retainedSharedCompanies == 0)
        #expect(try context.fetch(FetchDescriptor<UserAccountRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CompanyRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DeadlineRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ShareCertificateRecord>()).isEmpty)
    }

    @Test
    func deletingOneAccountRetainsSharedCompanyAndAnonymizesAuditActor() throws {
        let context = try makeContext()
        let deletedAccount = UserAccountRecord(
            email: "leaving@example.se",
            displayName: "Leaving"
        )
        let remainingAccount = UserAccountRecord(
            email: "remaining@example.se",
            displayName: "Remaining"
        )
        let company = CompanyRecord(
            organisationNumber: "556036-0793",
            registeredName: "Shared AB",
            status: .active,
            sourceName: "Test",
            sourceUpdatedAt: .now
        )
        context.insert(deletedAccount)
        context.insert(remainingAccount)
        context.insert(company)
        context.insert(
            CompanyMembershipRecord(
                accountID: deletedAccount.id,
                companyID: company.id,
                role: .owner
            )
        )
        context.insert(
            CompanyMembershipRecord(
                accountID: remainingAccount.id,
                companyID: company.id,
                role: .administrator
            )
        )
        context.insert(
            AuditEventRecord(
                companyID: company.id,
                accountID: deletedAccount.id,
                action: "updated",
                entityType: "company",
                entityID: company.id,
                summary: "Updated by leaving user"
            )
        )
        try context.save()

        let report = try AccountDeletionService().delete(
            accountID: deletedAccount.id,
            from: context
        )
        let accounts = try context.fetch(FetchDescriptor<UserAccountRecord>())
        let companies = try context.fetch(FetchDescriptor<CompanyRecord>())
        let events = try context.fetch(FetchDescriptor<AuditEventRecord>())

        #expect(report.deletedCompanies == 0)
        #expect(report.retainedSharedCompanies == 1)
        #expect(accounts.map(\.id) == [remainingAccount.id])
        #expect(companies.map(\.id) == [company.id])
        #expect(events.count == 1)
        #expect(events.first?.accountID == nil)
        #expect(events.first?.summary == "Händelsen utfördes av ett raderat konto.")
    }

    @Test
    func deletingAccountRemovesOnlyItsGeneratedArtifacts() throws {
        let context = try makeContext()
        let deletedAccount = UserAccountRecord(
            email: "owner@example.se",
            displayName: "Owner"
        )
        let retainedAccount = UserAccountRecord(
            email: "shared@example.se",
            displayName: "Shared"
        )
        let deletedCompany = CompanyRecord(
            organisationNumber: "556016-0680",
            registeredName: "Deleted AB",
            status: .active,
            sourceName: "Test",
            sourceUpdatedAt: .now
        )
        let retainedCompany = CompanyRecord(
            organisationNumber: "556036-0793",
            registeredName: "Retained AB",
            status: .active,
            sourceName: "Test",
            sourceUpdatedAt: .now
        )
        context.insert(deletedAccount)
        context.insert(retainedAccount)
        context.insert(deletedCompany)
        context.insert(retainedCompany)
        context.insert(
            CompanyMembershipRecord(
                accountID: deletedAccount.id,
                companyID: deletedCompany.id,
                role: .owner
            )
        )
        context.insert(
            CompanyMembershipRecord(
                accountID: deletedAccount.id,
                companyID: retainedCompany.id,
                role: .owner
            )
        )
        context.insert(
            CompanyMembershipRecord(
                accountID: retainedAccount.id,
                companyID: retainedCompany.id,
                role: .administrator
            )
        )
        try context.save()

        let fileManager = FileManager.default
        let supportRoot = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? fileManager.removeItem(at: supportRoot) }

        let generatedRoot = supportRoot
            .appending(path: "GeneratedDocuments", directoryHint: .isDirectory)
        let deletedCompanyDirectory = generatedRoot
            .appending(path: deletedCompany.id.uuidString, directoryHint: .isDirectory)
        let retainedCompanyDirectory = generatedRoot
            .appending(path: retainedCompany.id.uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: deletedCompanyDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: retainedCompanyDirectory,
            withIntermediateDirectories: true
        )
        try Data("deleted".utf8).write(
            to: deletedCompanyDirectory.appending(path: "overview.pdf")
        )
        try Data("retained".utf8).write(
            to: retainedCompanyDirectory.appending(path: "overview.pdf")
        )

        let vaultDirectory = supportRoot
            .appending(path: "Documents", directoryHint: .isDirectory)
            .appending(path: deletedCompany.id.uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: vaultDirectory,
            withIntermediateDirectories: true
        )
        let vaultFile = vaultDirectory.appending(path: "evidence.pdf")
        try Data("vault".utf8).write(to: vaultFile)
        context.insert(
            DocumentRecord(
                companyID: deletedCompany.id,
                title: "Evidence",
                category: .other,
                fileBookmark: try vaultFile.bookmarkData(),
                sourceName: "Test"
            )
        )
        try context.save()

        let exportsRoot = supportRoot
            .appending(path: "SecureExports", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: exportsRoot,
            withIntermediateDirectories: true
        )
        let deletedExport = exportsRoot.appending(
            path: "NorthBridge-data-\(deletedAccount.id.uuidString.prefix(8)).json"
        )
        let retainedExport = exportsRoot.appending(
            path: "NorthBridge-data-\(retainedAccount.id.uuidString.prefix(8)).json"
        )
        try Data("deleted".utf8).write(to: deletedExport)
        try Data("retained".utf8).write(to: retainedExport)

        _ = try AccountDeletionService(
            fileManager: fileManager,
            applicationSupportDirectory: supportRoot
        ).delete(accountID: deletedAccount.id, from: context)

        #expect(fileManager.fileExists(atPath: deletedCompanyDirectory.path) == false)
        #expect(fileManager.fileExists(atPath: retainedCompanyDirectory.path))
        #expect(fileManager.fileExists(atPath: vaultFile.path) == false)
        #expect(fileManager.fileExists(atPath: deletedExport.path) == false)
        #expect(fileManager.fileExists(atPath: retainedExport.path))
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: BolagscenterSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        return ModelContext(container)
    }
}

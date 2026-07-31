import Foundation
import SwiftData
import Testing
@testable import Bolagscenter

@MainActor
struct AccountDataExportServiceTests {
    @Test
    func portableExportIncludesShareCertificateHistory() throws {
        let context = try makeContext()
        let account = UserAccountRecord(
            email: "owner@example.se",
            displayName: "Owner"
        )
        let company = CompanyRecord(
            organisationNumber: "5560160680",
            registeredName: "NorthBridge Test AB",
            status: .active,
            sourceName: "Test",
            sourceUpdatedAt: .now
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
        let certificate = ShareCertificateRecord(
            companyID: company.id,
            shareholderID: shareholder.id,
            shareClassID: shareClass.id,
            certificateNumber: "AB-2026-01",
            quantity: 100,
            issuedAt: .now,
            status: .issued
        )
        context.insert(account)
        context.insert(company)
        context.insert(shareholder)
        context.insert(shareClass)
        context.insert(certificate)
        context.insert(
            CompanyMembershipRecord(
                accountID: account.id,
                companyID: company.id,
                role: .owner
            )
        )
        try context.save()

        let url = try AccountDataExportService().export(
            accountID: account.id,
            from: context
        )
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(PortableAccountExport.self, from: data)
        let exportedCertificate = export.records.first {
            $0.type == "shareCertificate" && $0.id == certificate.id
        }

        #expect(exportedCertificate?.attributes["certificateNumber"] == "AB-2026-01")
        #expect(exportedCertificate?.attributes["status"] == "issued")
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

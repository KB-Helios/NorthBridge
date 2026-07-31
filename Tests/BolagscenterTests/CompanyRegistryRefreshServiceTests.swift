import Foundation
import SwiftData
import Testing
@testable import Bolagscenter

@MainActor
struct CompanyRegistryRefreshServiceTests {
    @Test
    func successfulRefreshUpdatesSourceTimestampsAndAuditAtomically()
        async throws {
        let context = try makeContext()
        let company = makeCompany()
        context.insert(company)
        try context.save()

        let sourceUpdatedAt = Date(timeIntervalSince1970: 1_785_484_800)
        let synchronizedAt = Date(timeIntervalSince1970: 1_785_488_400)
        let value = RegisteredCompany(
            organisationNumber: try OrganisationNumber("5560160680"),
            registeredName: "Verifierat Testbolag AB",
            status: .active,
            registeredOffice: "Stockholm",
            sourceName: "Testregister",
            sourceUpdatedAt: sourceUpdatedAt
        )
        let service = CompanyRegistryRefreshService(
            registry: StubRegistry(result: .success(value)),
            permissionPolicy: PermissionPolicy()
        )

        let result = try await service.refresh(
            company: company,
            accountID: UUID(),
            role: .owner,
            profiles: [],
            integrations: [],
            in: context,
            now: synchronizedAt
        )

        let integrations = try context.fetch(
            FetchDescriptor<IntegrationRecord>()
        )
        let profiles = try context.fetch(
            FetchDescriptor<CompanyProfileRecord>()
        )
        let audit = try context.fetch(
            FetchDescriptor<AuditEventRecord>()
        )

        #expect(result.sourceName == "Testregister")
        #expect(company.registeredName == "Verifierat Testbolag AB")
        #expect(company.status == .active)
        #expect(company.sourceUpdatedAt == sourceUpdatedAt)
        #expect(company.lastSynchronizedAt == synchronizedAt)
        #expect(company.isStale == false)
        #expect(integrations.first?.state == .connected)
        #expect(integrations.first?.lastSuccessfulAt == synchronizedAt)
        #expect(profiles.first?.registeredOffice == "Stockholm")
        #expect(audit.first?.action == "company.registry.refreshed")
    }

    @Test
    func failedRefreshPreservesSourceDataAndMarksCachedDataStale()
        async throws {
        let context = try makeContext()
        let company = makeCompany()
        let originalSourceDate = company.sourceUpdatedAt
        let originalSyncDate = Date(timeIntervalSince1970: 1_780_000_000)
        company.lastSynchronizedAt = originalSyncDate
        context.insert(company)
        try context.save()

        let expectedError = IntegrationAdapterError.notConfigured(
            provider: "Testregister"
        )
        let service = CompanyRegistryRefreshService(
            registry: StubRegistry(result: .failure(expectedError)),
            permissionPolicy: PermissionPolicy()
        )

        do {
            _ = try await service.refresh(
                company: company,
                accountID: UUID(),
                role: .owner,
                profiles: [],
                integrations: [],
                in: context
            )
            Issue.record("Uppdateringen skulle ha misslyckats.")
        } catch let error as IntegrationAdapterError {
            #expect(error == expectedError)
        }

        let integration = try #require(
            context.fetch(FetchDescriptor<IntegrationRecord>()).first
        )
        #expect(company.registeredName == "Lokalt Testbolag AB")
        #expect(company.sourceUpdatedAt == originalSourceDate)
        #expect(company.lastSynchronizedAt == originalSyncDate)
        #expect(company.isStale)
        #expect(integration.state == .disconnected)
        #expect(integration.lastSuccessfulAt == nil)
    }

    @Test
    func permissionPolicyPreventsRegistryMutation() async throws {
        let context = try makeContext()
        let company = makeCompany()
        context.insert(company)
        try context.save()

        let service = CompanyRegistryRefreshService(
            registry: StubRegistry(
                result: .failure(
                    .unavailable(provider: "Testregister")
                )
            ),
            permissionPolicy: PermissionPolicy()
        )

        await #expect(
            throws: CompanyRegistryRefreshError.permissionDenied
        ) {
            _ = try await service.refresh(
                company: company,
                accountID: UUID(),
                role: .readOnlyAdvisor,
                profiles: [],
                integrations: [],
                in: context
            )
        }
        #expect(
            try context.fetch(
                FetchDescriptor<IntegrationRecord>()
            ).isEmpty
        )
    }

    private func makeCompany() -> CompanyRecord {
        CompanyRecord(
            organisationNumber: "5560160680",
            registeredName: "Lokalt Testbolag AB",
            status: .unknown,
            sourceName: "Manuellt angivet",
            sourceUpdatedAt: Date(timeIntervalSince1970: 1_770_000_000)
        )
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

private struct StubRegistry: CompanyRegistryService {
    let result: Result<RegisteredCompany, IntegrationAdapterError>

    func searchCompany(
        organisationNumber: OrganisationNumber
    ) async throws -> RegisteredCompany {
        try result.get()
    }

    func fetchCompanyDetails(
        organisationNumber: OrganisationNumber
    ) async throws -> RegisteredCompany {
        try result.get()
    }
}
